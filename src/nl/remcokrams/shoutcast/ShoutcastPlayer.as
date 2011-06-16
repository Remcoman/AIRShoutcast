package nl.remcokrams.shoutcast
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import nl.remcokrams.shoutcast.audioformat.IAudioFormatHandler;
	import nl.remcokrams.shoutcast.audioformat.aac.AACHandler;
	import nl.remcokrams.shoutcast.audioformat.mp3.MP3Handler;
	import nl.remcokrams.shoutcast.events.ShoutcastMetadataEvent;
	import nl.remcokrams.shoutcast.events.ShoutcastPlayerEvent;
	import nl.remcokrams.shoutcast.net.ShoutcastHTTPClient;
	
	[Event(name='metadata_available',type='nl.remcokrams.shoutcast.events.ShoutcastMetadataEvent')]
	[Event(name='state_change',type='nl.remcokrams.shoutcast.events.ShoutcastPlayerEvent')]
	[Event(name='phase_change',type='nl.remcokrams.shoutcast.events.ShoutcastPlayerEvent')]
	
	/**
	 * 
	 * @author remcokrams
	 * 
	 * The ShoutcastPlayer plays AAC & MP3 streams by default and can be extended with more formats by using registerAudioFormatHandler.<br><br>.
	 * Because of plugin and cross domain limitations the player will only work in Adobe AIR.
	 * 
	 * 
	 * Usage:
	 * <code><pre>
	 * 
	 * var player:ShoutcastPlayer = new ShoutcastPlayer();
	 * player.play(streamURL);
	 * 
	 * player.addEventListener(ShoutcastMetadataEvent.METADATA_AVAILABLE, function (e:ShoutcastMetadataEvent):void {
	 * 	trace(e.metadata.StreamTitle);
	 * });
	 * 
	 * </pre></code>
	 * 
	 * TODO:<br> 
	 * 
	 * <ul>
	 * 	<li>Make mp3 playback more reliable (sometimes it fails to connect)</li>
	 * 	<li>Optimize byte access by using apparat</li>
	 * </ul>
	 * 
	 */	
	
	public class ShoutcastPlayer extends EventDispatcher
	{
		public static const DEFAULT_FORMAT_HANDLERS:Vector.<Class> = Vector.<Class>([
			AACHandler,
			MP3Handler
		]);
		
		private static const RESET_PLAYBACK:int = 1;
		private static const RESET_PROPS:int = 2;
		private static const RESET_STREAM:int  = 3;
		
		protected var _flvAudioStreamWriter:FLVAudioStreamWriter;
		protected var _request:URLRequest;
		protected var _stream:ShoutcastHTTPClient;
		protected var _streamInfo:StreamInfo;
		protected var _currentAudioHandler:IAudioFormatHandler;
		protected var _audioFormatHandlers:Object = {};
		protected var _state:String;
		protected var _phase:int;
		protected var _lastErrorCode:int;
		protected var _emptyStreamStartTime:int;
		protected var _streamReader:ShoutcastStreamReader;
		protected var _bufferMonitor:Timer;
		protected var _autoReconnect:Boolean;
		
		public function ShoutcastPlayer()
		{	
			init();
		}
		
		/**
		 * 
		 * Set the new soundTransform (volume, panning) of the player.<br>
		 * When setting the volume of the player always reassign the soundTransform! Like so:<br>
		 * 
		 * <code><pre>
		 * 
		 * var st:SoundTransform = player.soundTransform;
		 * st.volume = .5;
		 * player.soundTransform = st;
		 * 
		 * </pre></code>
		 *  
		 * @see flash.media.SoundTransform
		 * @param value 
		 * 
		 */		
		public function set soundTransform(value:SoundTransform):void {
			_flvAudioStreamWriter.soundTransform = value;
		}
		public function get soundTransform():SoundTransform {
			return _flvAudioStreamWriter.soundTransform;
		}
		
		/**
		 * 
		 * Register a new audioformat handler
		 *  
		 * @param handler a object which implement the IAudioFormatHandler interface
		 * 
		 */		
		public function registerAudioFormatHandler(handler:IAudioFormatHandler):void {
			var compatibleTypes:Vector.<String> = handler.compatibleContentTypes;
			for each(var contentType:String in compatibleTypes)
				_audioFormatHandlers[contentType] = handler;
		}
		
		public function get bufferFillPercentage():Number {
			return _flvAudioStreamWriter.bufferFilledPercentage;
		}
		
		
		/**
		 * Autoreconnect will periodically try to reconnect to the shoutcast server if it determines that the connection has been lost.
		 * 
		 * A lost connection is determined by stream which has bytesAvailable==0 for 2 seconds
		 *   
		 * @return 
		 * 
		 */		
		public function get autoReconnect():Boolean {
			return _autoReconnect;
		}
		public function set autoReconnect(value:Boolean):void {
			_autoReconnect = value;
		}
		
		/**
		 *  
		 * @see nl.remcokrams.shoutcast.ShoutcastPlayerStates
		 * @return a string describing the state of the player 
		 * 
		 */		
		public function get state():String {
			return _state;
		}
		
		/**
		 * @see nl.remcokrams.shoutcast.ShoutcastPlayerPhase 
		 * @return a string describing the phase of the player
		 * 
		 */		
		public function get phase():int {
			return _phase;
		}
		
		/**
		 * 
		 * @see nl.remcokrams.shoutcast.StreamInfo 
		 * @return a object which contains info about the current stream
		 * 
		 */		
		public function get streamInfo():StreamInfo {
			return _streamInfo;
		}
		
		/**
		 * @see nl.remcokrams.shoutcast.ShoutcastPlayerErrors 
		 * @return the last error that occured
		 * 
		 */		
		public function get lastErrorCode():int {
			return _lastErrorCode;
		}
		
		/**
		 *
		 * Toggles the current state between pause and play<br>
		 * Doesn't do anything when the state is 'stopped' 
		 * 
		 */		
		public function togglePause():void {
			if(_state == ShoutcastPlayerStates.STOPPED)
				return;
			_state == ShoutcastPlayerStates.PAUSED ? play() : pause();
		}
		
		/**
		 *
		 * Pauses the playback but leaves the socket open and keeps data in buffers so playback can start immediately when calling play(null)   
		 * 
		 */		
		public function pause():void {
			if(_phase == ShoutcastPlayerPhase.ERROR || _phase == ShoutcastPlayerPhase.DISCONNECTED)
				return;
			
			_flvAudioStreamWriter.pause();
			_streamReader.pause();
			_bufferMonitor.stop();
			
			changeState( ShoutcastPlayerStates.PAUSED );
		}
		
		
		/**
		 *  
		 * Start playing a new stream or resume playing of a paused stream
		 * 
		 * @param url the url of the stream to play or null if you want to continue a paused stream
		 * 
		 */		
		public function play(url:String=null):void {
			if(url != null)
			{
				reset(RESET_PROPS);
				
				_request = createRequest(url);
				_stream.connect(_request);
				_streamInfo = new StreamInfo( _request.url );
				
				changePhase( ShoutcastPlayerPhase.CONNECTING );
			}
			else
			{
				if(_phase == ShoutcastPlayerPhase.ERROR || _phase == ShoutcastPlayerPhase.DISCONNECTED)
					return;
				
				_flvAudioStreamWriter.resume();
				_streamReader.resume();
				_bufferMonitor.start();
			}
				
			changeState( ShoutcastPlayerStates.PLAYING );
		}
		
		/**
		 *
		 * Stop playback of a stream 
		 * 
		 */		
		public function stop():void {
			if(_phase == ShoutcastPlayerPhase.DISCONNECTED)
				return;
			
			reset(RESET_STREAM);
			
			changePhase( ShoutcastPlayerPhase.DISCONNECTED );
			changeState( ShoutcastPlayerStates.STOPPED );
		}
		
		
		
		/*
		
		Protected functions
		
		*/
		
		protected function createRequest(url:String):URLRequest {
			var request:URLRequest = new URLRequest(url);
			request.userAgent = "Winamp"; //faking WinAmp
			request.requestHeaders = [ new URLRequestHeader("Icy-MetaData", "1") ]; //this is needed
			return request;
		} 
		
		protected function reset(what:int):void {
			if(what > RESET_PLAYBACK)
			{
				_streamReader.stop();
				_bufferMonitor.stop();
				_flvAudioStreamWriter.stop();
			}
			
			if(what > RESET_PROPS)
			{
				_request = null;
				_lastErrorCode = 0;
				_emptyStreamStartTime = 0;
				_streamInfo = null;
			}
			
			if(what > RESET_STREAM)
			{
				if(_currentAudioHandler)
					_currentAudioHandler.reset();
				_currentAudioHandler = null;
				
				_stream.close();
			}
		}
		
		protected function onSocketProgress():void {
			
			/*
				This happens when we did not get the shoutcast info in the response headers.
				Now we have to read it from the body. 
			
				First we buffer 1024 bytes (again a magic number) and use _streamInfo.parseFromBody to parse the headers from the body.
				We might still have some bytes left from those 1024 so we pass those to _streamReader.read
			*/
			if(!_streamInfo.isValid && _stream.bytesAvailable >= 1024)
			{
				var buffer:ByteArray = new ByteArray();
				_stream.readBytes(buffer, 0, 1024);
				
				if( _streamInfo.parseFromBody(buffer) )
				{
					if(pickAudioHandler())
					{
						prepareToPlay();
						_streamReader.read(buffer, _flvAudioStreamWriter, false);
					}
					else
					{
						triggerError( ShoutcastPlayerErrors.INVALID_FORMAT );
					}
				}
				
				buffer.clear();
				buffer = null;
			}
		}
		
		protected function onSocketError(status:int):void {
			var errorCode:int;
			
			//translate http error to shoutcast error code
			switch(status) {
				case -1 :
					errorCode = ShoutcastPlayerErrors.SOCKET_ERROR;
					break;
				
				case 404 :
					errorCode = ShoutcastPlayerErrors.STREAM_NOT_FOUND;
					break;
				
				default : //server returned unknown status (not 200)
					errorCode = ShoutcastPlayerErrors.SERVER_ERROR;
					break;
			}
			
			triggerError( errorCode ); //TODO Socket error does not mean STREAM_NOT_FOUND
		}
		
		protected function onSocketResponse(status:int, headers:Vector.<URLRequestHeader>):void {
			changePhase( ShoutcastPlayerPhase.CONNECTED_TO_STREAM );
				
			if( _streamInfo.parseFromHeaders(headers) ) //parse the info from the response headers
			{
				if( pickAudioHandler() )
					prepareToPlay();
				else
					triggerError( ShoutcastPlayerErrors.INVALID_FORMAT );
			}
			else
			{
				_stream.progressCallback = onSocketProgress; //try to parse it from the body
			}
		}
		
		protected function pickAudioHandler():Boolean {
			_currentAudioHandler = IAudioFormatHandler( _audioFormatHandlers[ _streamInfo.contentType ] );
			
			if(_currentAudioHandler)
				trace("Attempting to use handler " + _currentAudioHandler + " for " + _streamInfo.contentType);
			
			return _currentAudioHandler && _currentAudioHandler.init(_streamInfo);
		}
		
		protected function prepareToPlay():void {
			/*
				Start the shoutcast flv transcoding engine
			*/
			
			_flvAudioStreamWriter.play();
			_streamReader.start(_streamInfo, _currentAudioHandler);
			_bufferMonitor.start();
			_stream.progressCallback = null;
			
			changePhase( ShoutcastPlayerPhase.BUFFERING_START );
		}
		
		protected function monitorStream(e:Event=null):void {
			if(!_flvAudioStreamWriter.needMoreData) //we got enough data to play...so leave now
				return;
			
			if(_stream.bytesAvailable == 0 && _autoReconnect)
			{
				var t:int = getTimer();
				
				if(_emptyStreamStartTime == 0)
					_emptyStreamStartTime = t;
				
				if(t - _emptyStreamStartTime > 2000) //assume disconnected stream after 2 seconds
				{
					_emptyStreamStartTime = 0;
					reset(RESET_PLAYBACK);
					_stream.startAutoReconnect();
					
					changePhase( ShoutcastPlayerPhase.BUFFERING_START );
				}
			}
			else
			{
				_streamReader.read(_stream, _flvAudioStreamWriter, true);
				
				var playing:Boolean = _flvAudioStreamWriter.bufferLength >= _flvAudioStreamWriter.bufferPlaybackTime;
				if(_phase != ShoutcastPlayerPhase.BUFFERING_START && !playing) //buffer still not filled to max
					changePhase( ShoutcastPlayerPhase.BUFFERING_START );
				else if( _phase != ShoutcastPlayerPhase.BUFFERING_END && playing ) //buffer filled to max
					changePhase( ShoutcastPlayerPhase.BUFFERING_END );
			}
		}
		
		protected function onMetadata(value:String):void {
			if(value)
				dispatchEvent( new ShoutcastMetadataEvent(ShoutcastMetadataEvent.METADATA_AVAILABLE, false, false, value) );
		}
		
		protected function init():void {
			_state = ShoutcastPlayerStates.STOPPED;
			
			_flvAudioStreamWriter = new FLVAudioStreamWriter();
			
			_streamReader = new ShoutcastStreamReader();
			_streamReader.metadataCallback = onMetadata;
			
			_bufferMonitor = new Timer(1000);
			_bufferMonitor.addEventListener(TimerEvent.TIMER, monitorStream);
			
			_stream = new ShoutcastHTTPClient();
			_stream.responseCallback = onSocketResponse;
			_stream.errorCallback	= onSocketError;
			
			var clz:Class;
			
			for each(clz in DEFAULT_FORMAT_HANDLERS)
				registerAudioFormatHandler( IAudioFormatHandler( new clz() ) );
		}
		
		protected function changePhase( newPhase:int ):void {
			trace("ShoutcastPlayer phase: " + newPhase);
			
			if(newPhase != _phase)
			{
				_phase = newPhase;
				dispatchEvent( new ShoutcastPlayerEvent(ShoutcastPlayerEvent.PHASE_CHANGE, _state, _phase, _lastErrorCode) );
			}
		}
		
		protected function changeState( newState:String ):void {
			trace("ShoutcastPlayer state: " + newState);
			
			if(newState != _state)
			{
				_state = newState;
				dispatchEvent( new ShoutcastPlayerEvent(ShoutcastPlayerEvent.STATE_CHANGE, _state, _phase, _lastErrorCode) );
			}
		}
		
		protected function triggerError( code:int ):void {
			reset(RESET_STREAM);
			
			_lastErrorCode = code;
			
			changePhase( ShoutcastPlayerPhase.ERROR );
			changeState( ShoutcastPlayerStates.STOPPED );
		}
		
	}
}