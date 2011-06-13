package nl.remcokrams.shoutcast
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	/**
	 *	Created by remcokrams
	 *	Apr 25, 2011	
	 * 
	 *  FLV specification: http://download.macromedia.com/f4v/video_file_format_spec_v10_1.pdf
	 * 
	 **/
	
	public class FLVTag
	{
		/**
		 *  Other formats are not really worth mentioning
		 */		
		public static const TYPE_MP3:int = 2;
		public static const TYPE_AAC:int = 10;
		public static const TYPE_SPEEX:int = 11;
		
		public static const SAMPLERATE_5500:int = 0;
		public static const SAMPLERATE_11000:int = 1;
		public static const SAMPLERATE_22000:int = 2;
		public static const SAMPLERATE_44000:int = 3;
		
		public static const SOUNDSIZE_8BIT:int = 0;
		public static const SOUNDSIZE_16BIT:int = 1;
		
		public static const SOUNDTYPE_MONO:int = 0;
		public static const SOUNDTYPE_STEREO:int = 1;
		
		public var complete:Boolean;
		
		public var duration:uint;
		public var isAudioSpecificConfig:Boolean; //AAC sequence header
		public var payload:ByteArray = new ByteArray();
		public var type:uint;
		public var sampleRate:uint;
		public var monoOrStereo:uint;
		public var soundSize:uint;
		
		public function FLVTag():void {
			payload.endian = Endian.BIG_ENDIAN;
		}
		
		public function toString():String {
			return "Header: " + isAudioSpecificConfig + ", Type: " + type + ", Samplerate: " + sampleRate + ", Duration: " + duration + ", MonoOrStereo: " + monoOrStereo; 
		}
	}
}