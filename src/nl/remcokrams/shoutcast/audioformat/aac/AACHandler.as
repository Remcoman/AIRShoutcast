package nl.remcokrams.shoutcast.audioformat.aac
{
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.IDataInput;
	
	import nl.remcokrams.shoutcast.FLVTag;
	import nl.remcokrams.shoutcast.StreamInfo;
	import nl.remcokrams.shoutcast.audioformat.IAudioFormatHandler;
	
	
	/**
	 *	Created by remcokrams
	 *	Apr 25, 2011	
	 **/
	
	public class AACHandler implements IAudioFormatHandler
	{
		private static const CONTENT_TYPES:Vector.<String> = Vector.<String>([
			"audio/aacp",
			"audio/aac"
		]);
		
		private static const MODE_AUDIO:int = 1;
		private static const MODE_ADTS:int = 2;
		
		protected var _info:StreamInfo;
		protected var _mode:int;
		protected var _audioBuffer:ByteArray;
		protected var _adtsHeader:ADTSHeader;
		protected var _adtsBuffer:ByteArray;
		protected var _wroteAudioSpecificConfig:Boolean;
		
		public function AACHandler()
		{
			_adtsHeader = new ADTSHeader();
			
			_adtsBuffer = new ByteArray();
			_adtsBuffer.endian = Endian.BIG_ENDIAN;
			
			_audioBuffer = new ByteArray();
			_audioBuffer.endian = Endian.BIG_ENDIAN;
		}
		
		public function get compatibleContentTypes():Vector.<String>
		{
			return CONTENT_TYPES;
		}
		
		public function init(info:StreamInfo):Boolean
		{
			_info = info;
			_mode = MODE_ADTS;
			return true;
		}
		
		public function reset():void {
			_adtsBuffer.clear();
			_audioBuffer.clear();
		}
		
		protected function appendBytes(into:ByteArray, from:IDataInput, length:int):void {
			if(length <= 0)
				return;
			from.readBytes(into, into.length, length);
			into.position = 0;
		}
		
		protected function configFLVTag(flvTag:FLVTag, payload:ByteArray, isAudioSpecificConfig:Boolean):void {
			flvTag.isAudioSpecificConfig = isAudioSpecificConfig;
			flvTag.duration = flvTag.isAudioSpecificConfig ? 0 : _adtsHeader.duration;
			
			flvTag.payload = payload;
			
			flvTag.type = FLVTag.TYPE_AAC;
			flvTag.soundSize = FLVTag.SOUNDSIZE_16BIT;
			flvTag.monoOrStereo = FLVTag.SOUNDTYPE_STEREO;
			flvTag.sampleRate = FLVTag.SAMPLERATE_44000;
			flvTag.complete = true;
		}
		
		public function readMore(stream:IDataInput, flvTag:FLVTag, readMax:int):int
		{
			var canRead:int = 0;
			
			if(_mode == MODE_ADTS)
			{
				canRead = Math.min(readMax, 7 - _adtsBuffer.length); //can also be 9
				
				appendBytes(_adtsBuffer, stream, canRead);
				
				if(_adtsBuffer.length >= 7) //can also be 9
				{
					_adtsHeader.parse( _adtsBuffer );
					
					if(!_wroteAudioSpecificConfig)
					{
						configFLVTag(flvTag, _adtsHeader.toAudioSpecificConfig() , true);
						_wroteAudioSpecificConfig = true;
					}
					
					_adtsBuffer.clear();
					_audioBuffer.clear();
					
					_mode = MODE_AUDIO;
				}
			}
			else if(_mode == MODE_AUDIO)
			{
				canRead = Math.min(readMax, _adtsHeader.frameLengthMinusHeader - _audioBuffer.length);
				
				appendBytes(_audioBuffer, stream, canRead);
				
				if(_audioBuffer.length >= _adtsHeader.frameLengthMinusHeader)
				{	
					//flush buffer
					configFLVTag(flvTag, _audioBuffer, false);
					
					_mode = MODE_ADTS;
				}
			}
			
			return canRead;
		}
	}
}