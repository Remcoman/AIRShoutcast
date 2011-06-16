package nl.remcokrams.shoutcast.audioformat.mp3
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	/**
	 *	Created by remcokrams
	 *  
	 *  Documentation mp3:
	 *  - http://www.mp3-tech.org/programmer/frame_header.html
	 *  - http://www.codeproject.com/KB/audio-video/mpegaudioinfo.aspx
	 * 
	 *	Apr 28, 2011	
	 **/
	
	public class MP3Header
	{
		public static const MPEG_V25_SAMPLERATES:Vector.<uint> = Vector.<uint>([11025, 12000, 8000, 0]);
		public static const MPEG_V2_SAMPLERATES:Vector.<uint> = Vector.<uint>([22050, 24000, 16000, 0]);
		public static const MPEG_V1_SAMPLERATES:Vector.<uint> = Vector.<uint>([44100, 48000, 32000, 0]);
		
		public static const BITRATE_TABLE:Vector.<Vector.<uint>> = Vector.<Vector.<uint>>([
			Vector.<uint>([	  0,   0,   0,   0,   0]),
			Vector.<uint>([  32,  32,  32,  32,   8]),
			Vector.<uint>([  64,  48,  40,  48,  16]),
			Vector.<uint>([  96,  56,  48,  56,  24]),
			Vector.<uint>([ 128,  64,  56,  64,  32]),
			Vector.<uint>([ 160,  80,  64,  80,  40]),
			Vector.<uint>([ 192,  96,  80,  96,  48]),
			Vector.<uint>([ 224, 112,  96, 112,  56]),
			Vector.<uint>([ 256, 128, 112, 128,  64]),
			Vector.<uint>([ 288, 160, 128, 144,  80]),
			Vector.<uint>([ 320, 192, 160, 160,  96]),
			Vector.<uint>([ 352, 224, 192, 176, 112]),
			Vector.<uint>([ 384, 256, 224, 192, 128]),
			Vector.<uint>([ 416, 320, 256, 224, 144]),
			Vector.<uint>([ 448, 384, 320, 256, 160]),
			Vector.<uint>([   0,   0,   0,   0,   0])
		]);
		
		public static const SAMPLES_PER_FRAME_TABLE:Vector.<Vector.<uint>> = Vector.<Vector.<uint>>([
			Vector.<uint>([ 384,  384,  384]), //Layer I
			Vector.<uint>([1152, 1152, 1152]), //Layer II
			Vector.<uint>([1152,  576,  576])  //Layer III
		]);
		
		public static const MPEG_LAYERS:Vector.<uint> = Vector.<uint>( [0,3,2,1] );
		public static const MPEG_VERSIONS:Vector.<uint> = Vector.<uint>( [3,0,2,1] );
		
		public static const STEREO:uint 		= 0;
		public static const JOINT_STEREO:uint   = 1;
		public static const DUAL_CHANNEL:uint   = 2;
		public static const SINGLE_CHANNEL:uint = 3;
		
		public var versionID:uint;
		public var layer:uint;
		public var padding:uint;
		public var bitRateIndex:uint; //meaning of this property. Check: http://www.mp3-tech.org/programmer/frame_header.html
		public var actualBitRate:uint;
		public var protectionAbsense:uint;
		public var sampleRateIndex:uint;
		public var actualSampleRate:uint;
		public var isStereo:Boolean;
		public var channels:uint;
		public var frameLength:uint;
		public var duration:uint;
		
		public function MP3Header()
		{
		}
		
		/**
		 *
		 * Shoutcast streams start with mp3 frames which are not byte aligned.
		 * Easiest (and best) way is to wait for a byte aligned frame and start processing from there
		 *  
		 * @param buffer
		 * @param mustEqualHeader the header to match (if not matching then the stream is corrupt or we have a bug in the parsing process)
		 * @return 
		 * 
		 */		
		public function findAndParse(buffer:ByteArray, mustEqualHeader:MP3Header):Boolean {
			var byte:uint;
			
			while(buffer.bytesAvailable)
			{
				byte = buffer.readUnsignedByte();
				
				if(byte == 0xFF) {
					buffer.position--;
					
					if(buffer.bytesAvailable >= 4)
					{
						if(parse(buffer, mustEqualHeader) )
							return true;
						else
							buffer.position++;
					}
					else
					{
						break;
					}
				}
				
			}
			
			return false;
		}
		
		public function clone():MP3Header {
			var cloneHeader:MP3Header = new MP3Header();
			
			cloneHeader.actualBitRate = actualBitRate;
			cloneHeader.actualSampleRate = actualSampleRate;
			cloneHeader.bitRateIndex = bitRateIndex;
			cloneHeader.channels = channels;
			cloneHeader.isStereo = isStereo;
			cloneHeader.layer = layer;
			cloneHeader.versionID = versionID;
			
			return cloneHeader;
		}
		
		public function equals(otherHeader:MP3Header):Boolean {
			return versionID == otherHeader.versionID && 
				   layer == otherHeader.layer &&
				   actualSampleRate == otherHeader.actualSampleRate;
		}
		
		public function parse(buffer:ByteArray, mustEqualHeader:MP3Header):Boolean {
			var bits:uint = buffer.readUnsignedInt();
			
			buffer.position -= 4;
			
			if((bits >>> 21) == 0x7FF)
			{
				versionID = MPEG_VERSIONS[ (bits >>> 19) & 3 ];
				layer = MPEG_LAYERS[ (bits >>> 17) & 3 ];
				protectionAbsense = (bits >>> 16) & 1;
				bitRateIndex = (bits >>> 12) & 0xF;
				padding = (bits >>> 9) & 1;
				sampleRateIndex = (bits >>> 10) & 3;
				channels = (bits >>> 6) & 3;
				isStereo = channels < 3;
				
				var columnIndex:uint;
				if(versionID == 1 && layer == 1)
					columnIndex = 0;
				else if(versionID == 1 && layer == 2)
					columnIndex = 1;
				else if(versionID == 1 && layer == 3)
					columnIndex = 2;
				else if(versionID == 2 && layer == 1)
					columnIndex = 3;
				else if(versionID == 2 && (layer == 2 || layer == 3))
					columnIndex = 4;
				actualBitRate = BITRATE_TABLE[ bitRateIndex ][ columnIndex ] * 1000;
				
				switch(versionID)
				{
					case 2 : //MPEG Version 2
						actualSampleRate = MPEG_V2_SAMPLERATES[ sampleRateIndex ];
						break;
					
					case 1 : //MPEG version 1
						actualSampleRate = MPEG_V1_SAMPLERATES[ sampleRateIndex ];
						break;
					
					case 3 : //MPEG Version 2.5
						actualSampleRate = MPEG_V25_SAMPLERATES[ sampleRateIndex ];
						break;
				}
				
				if(!actualBitRate || !actualSampleRate) //invalid bitrate or samplerate
					return false;
				
				if(mustEqualHeader && !mustEqualHeader.equals(this)) //some fields which should be the same have changed
					return false;
				
				var samplesPerFrame:uint = SAMPLES_PER_FRAME_TABLE[ layer-1 ][ versionID-1 ];
				
				duration = (samplesPerFrame / actualSampleRate) * 1000;
				
				var bps:Number = (samplesPerFrame / 8);
				frameLength = ( (bps * actualBitRate) / actualSampleRate ) + 
							  (padding * (layer == 1 ? 4 : 1)) + //padding * slot size
							  (!protectionAbsense ? 2 : 0); //crc check (we don't this)
				
				return true;
			}
			
			return false;
		}
		
		public function toString():String {
			return "MP3 Version: " + versionID + ", Layer: " + layer + ", Padding: " + padding + ", Bitrate: " + actualBitRate + ", Samplerate: " + actualSampleRate + ", Size: " + frameLength + ", Duration: " + duration;
		}
	}
}