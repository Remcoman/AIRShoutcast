package nl.remcokrams.shoutcast.audioformat.aac
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	/**
	 *	Created by remcokrams
	 *	Apr 25, 2011	
	 **/
	
	public class ADTSHeader
	{
		public static const MPEG4_SAMPLERATES:Vector.<uint> = Vector.<uint>([
			96000,
			88200,
			64000,
			48000,
			44100,
			32000,
			24000,
			22050,
			16000,
			12000,
			11025,
			8000,
			7350
		]);
		
		public var protectionAbsense:uint;
		public var profileCode:uint;
		public var sampleRate:uint;
		public var channels:uint;
		public var frameLength:uint;
		public var duration:uint;
		public var frameLengthMinusHeader:uint;
		
		public function ADTSHeader()
		{
		}
		
		/**
		 *
		 * Partial implementation of audio specific config.
		 * 
		 * http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio
		 *  
		 * @return 
		 * 
		 */		
		public function toAudioSpecificConfig():ByteArray {
			var bytes:ByteArray = new ByteArray();
			bytes.endian = Endian.BIG_ENDIAN;
			bytes.writeShort( ( (profileCode << 8) | (sampleRate << 4) | channels) << 3);
			bytes.position = 0;
			return bytes;
		}
		
		public function parse(buffer:ByteArray):void {
			var bits1:uint = buffer.readUnsignedShort(), syncWord:uint = bits1 >> 4;
			
			if(syncWord == 0xFFF)
			{
				protectionAbsense = bits1 & 1;
				
				var bits2:uint = buffer.readUnsignedInt();
				
				profileCode = (bits2 >> 30) + 1;
				sampleRate = (bits2 >> 26) & 0xF;
				channels = (bits2 >> 22) & 0x7;
				
				duration = (1024 / MPEG4_SAMPLERATES[sampleRate]) * 1000;
				frameLength = (bits2 >> 5) & 0x1FFF;
				
				frameLengthMinusHeader = frameLength - (protectionAbsense == 1 ? 7 : 9);
			}
			else
			{
				throw new Error("Could not read ADTS");
			}
			
			buffer.position -= 7;
		}
	}
}