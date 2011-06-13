package nl.remcokrams.shoutcast.audioformat.mp3
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.IDataInput;
	
	import nl.remcokrams.shoutcast.FLVTag;
	import nl.remcokrams.shoutcast.StreamInfo;
	import nl.remcokrams.shoutcast.audioformat.IAudioFormatHandler;
	
	
	/**
	 *	Created by remcokrams
	 *	Apr 28, 2011	
	 * 
	 *  TODO: fix bug where stream sometimes won't connect
	 * 
	 **/
	
	public class MP3Handler implements IAudioFormatHandler
	{
		private static const MODE_HEADER:int = 1;
		private static const MODE_AUDIO:int = 2;
		
		protected var _streamInfo:StreamInfo;
		
		protected var _mode:int;
		protected var _firstValidHeader:MP3Header;
		protected var _header:MP3Header;
		
		protected var _frameBuffer:ByteArray;
		protected var _swapBuffer:ByteArray;
		protected var _tagBuffer:ByteArray;
		
		protected var _framesPerTag:uint = 2;
		protected var _frameCount:uint = 0;
		protected var _clearTagBuffer:Boolean;
		
		private static const CONTENT_TYPES:Vector.<String> = Vector.<String>([
			"audio/mp3",
			"audio/mpeg"
		]);
		
		public function MP3Handler()
		{
			_header = new MP3Header();
			_firstValidHeader = null;
			
			_frameBuffer = new ByteArray();
			_frameBuffer.endian = Endian.BIG_ENDIAN;
			
			_swapBuffer = new ByteArray();
			_swapBuffer.endian = Endian.BIG_ENDIAN;
			
			_tagBuffer = new ByteArray();
			_tagBuffer.endian = Endian.BIG_ENDIAN;
			
			_mode = MODE_HEADER;
		}
		
		public function get compatibleContentTypes():Vector.<String>
		{
			return CONTENT_TYPES;
		}
		
		public function init(info:StreamInfo):Boolean
		{
			_streamInfo = info;
			return true;
		}
		
		protected function configFLVTag(flvTag:FLVTag, payload:ByteArray):void {
			flvTag.isAudioSpecificConfig = false;
			
			payload.position = 0;
			flvTag.payload = payload;
			
			flvTag.type = FLVTag.TYPE_MP3;
			flvTag.soundSize = FLVTag.SOUNDSIZE_16BIT;
			flvTag.monoOrStereo = _header.isStereo ? FLVTag.SOUNDTYPE_STEREO : FLVTag.SOUNDTYPE_MONO;
			
			switch(_header.actualSampleRate)
			{
				case 22050 :
					flvTag.sampleRate = FLVTag.SAMPLERATE_22000;
					break;
				
				default :
					flvTag.sampleRate = FLVTag.SAMPLERATE_44000; //what to do?
					break;
			}
			flvTag.complete = true;
		}
		
		protected function appendBytes(into:ByteArray, from:IDataInput, length:int):void {
			if(length <= 0)
				return;
			from.readBytes(into, into.length, length);
			into.position = 0;
		}
		
		public function readMore(stream:IDataInput, flvTag:FLVTag, readMax:int):int
		{
			var canRead:int = 0;
			
			if(_mode == MODE_HEADER)
			{
				if(_clearTagBuffer)
				{
					flvTag.duration = 0;
					_tagBuffer.clear();
					_clearTagBuffer = false;
				}
				
				canRead = Math.min(readMax, 128 - _frameBuffer.length); //128 bytes is just a magic number
				
				appendBytes(_frameBuffer, stream, canRead);
				
				if(_frameBuffer.length == 128) //128 bytes is just a magic number
				{
					if( _header.findAndParse( _frameBuffer, _firstValidHeader ) )
					{
						if(!_firstValidHeader)
							_firstValidHeader = _header.clone();
						
						_mode = MODE_AUDIO;
					}

					_frameBuffer.readBytes(_swapBuffer); //read the remaining bytes into swap buffer
					_frameBuffer.clear(); //clear the frame buffer
					_frameBuffer.writeBytes(_swapBuffer); //write swap buffer into frame buffer
					_frameBuffer.position = 0;
					_swapBuffer.clear();
				}
			}
			else if(_mode == MODE_AUDIO)
			{
				canRead = Math.max( Math.min(readMax, _header.frameLength - _frameBuffer.length), 0);
				
				appendBytes(_frameBuffer, stream, canRead);
				
				if(_frameBuffer.length >= _header.frameLength)
				{	
					//flush buffer
					
					_tagBuffer.writeBytes(_frameBuffer);
					flvTag.duration += _header.duration;
					
					if(++_frameCount == _framesPerTag)
					{
						configFLVTag(flvTag, _tagBuffer);
						_frameCount = 0;
						_clearTagBuffer = true;
					}
					
					_frameBuffer.clear();
					_mode = MODE_HEADER;
				}
			}
			
			return canRead;
		}
		
		public function reset():void
		{
			_mode = MODE_HEADER;
			_frameCount = 0;
			_firstValidHeader = null;
			_tagBuffer.clear();
			_frameBuffer.clear();
			_swapBuffer.clear();
		}
	}
}