package nl.remcokrams.shoutcast
{
	import flash.utils.IDataInput;
	import flash.utils.Timer;
	
	import nl.remcokrams.shoutcast.audioformat.IAudioFormatHandler;
	
	/**
	 *	Created by remcokrams
	 *	May 24, 2011	
	 **/
	
	public class ShoutcastStreamReader
	{
		private static const MODE_HANDLER:int = 1;
		private static const MODE_METADATA:int = 2;
		
		protected var _handler:IAudioFormatHandler;
		protected var _streamInfo:StreamInfo;
		protected var _flvTag:FLVTag;
		protected var _mode:int;
		protected var _metadataLength:int = -1;
		protected var _readUntilNextMetadata:int = -1;
		
		public var metadataCallback:Function = function ():void {};
		
		public function ShoutcastStreamReader()
		{
			_flvTag = new FLVTag();
		}
		
		public function start(streamInfo:StreamInfo, handler:IAudioFormatHandler):void {
			_readUntilNextMetadata = streamInfo.metadataBytes;
			_handler = handler;
			_streamInfo = streamInfo;
			_mode = MODE_HANDLER;
			_metadataLength = -1;
		}
		
		public function resume():void {}
		
		public function pause():void {}
		
		public function stop():void {
			_handler = null;
			_streamInfo = null;
		}
		
		public function read(input:IDataInput, output:FLVAudioStreamWriter, readUntilPlay:Boolean=true):void {
			var handler:IAudioFormatHandler = _handler, 
				tag:FLVTag = _flvTag,
				bytesRead:uint;
			while(input.bytesAvailable > 0 && (readUntilPlay && output.bufferFilledPercentage < .99)) 
			{
				if(_mode == MODE_HANDLER)
				{	
					bytesRead = handler.readMore(input, tag, Math.min(_readUntilNextMetadata, input.bytesAvailable));
					
					if(tag.complete)
					{
						output.writeFLVTag(tag);
						tag.complete = false;
					}
					
					_readUntilNextMetadata -= bytesRead;
					
					if(_readUntilNextMetadata == 0)
						_mode = MODE_METADATA;
				}
				else if(_mode == MODE_METADATA)
				{
					if(_metadataLength == -1)
					{
						if(input.bytesAvailable >= 1)
							_metadataLength = input.readByte() * 16;
					}
					else if(input.bytesAvailable >= _metadataLength)
					{
						handleMetadata( input.readUTFBytes(_metadataLength) );
						
						if(_metadataLength > 0)
							output.beginFLV();
						
						_readUntilNextMetadata = _streamInfo.metadataBytes;
						_metadataLength = -1;
						
						_mode = MODE_HANDLER;
					}
				}
			}
			
		}
		
		protected function handleMetadata(value:String):void {
			if(value)
				metadataCallback(value);
		}
		
	}
}