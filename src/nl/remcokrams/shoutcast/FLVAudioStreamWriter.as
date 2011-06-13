package nl.remcokrams.shoutcast
{
	import flash.media.SoundTransform;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	/**
	 *	Created by remcokrams<br>
	 *	Apr 25, 2011	
	 * 
	 *  Implemented extended timestamp:
	 *  For more info see...http://www.impossibilities.com/v4/2008/08/29/a-problem-and-solution-for-flv-metadata-injectors-and-the-maximum-duration-of-flv-videos/
	 * 
	 **/
	
	public class FLVAudioStreamWriter
	{
		protected var _netConnection:NetConnection;
		protected var _netStream:NetStream;
		protected var _tagBytes:ByteArray;
		protected var _bufferFillTime:Number = 6;
		protected var _bufferThresholdPercentage:Number = .3;
		protected var _timestamp:uint = 0;
		
		public function FLVAudioStreamWriter()
		{
			_tagBytes = new ByteArray();
			_tagBytes.endian = Endian.BIG_ENDIAN;
			
			_netConnection = new NetConnection();
			_netConnection.connect(null);
			
			_netStream = new NetStream(_netConnection);
			_netStream.bufferTime = .2;
			_netStream.backBufferTime = 2;
		}
		
		public function set soundTransform(value:SoundTransform):void {
			_netStream.soundTransform = value;
		}
		
		public function get soundTransform():SoundTransform {
			return _netStream.soundTransform;
		}
		
		public function play():void {
			reset();
			_netStream.play(null);
			beginFLV();
		}
		
		public function pause():void {
			_netStream.pause();
		}
		
		public function resume():void {
			_netStream.resume();
		}
		
		public function stop():void {
			reset();
			_netStream.close();
		}
		
		public function get bufferFilledPercentage():Number {
			return _netStream.bufferLength / _bufferFillTime;
		}
		
		public function get needMoreData():Boolean {
			var bufferTimeLost:Number = _bufferFillTime - _netStream.bufferLength;
			return bufferTimeLost > (_bufferThresholdPercentage * _bufferFillTime);
		}
		
		/**
		 * 
		 * If the buffer length falls below this percentage of bufferFillTime
		 * Then the buffer will be filled to bufferFillTime
		 *  
		 * @return 
		 * 
		 */		
		public function get bufferThresholdPercentage():Number {
			return _bufferThresholdPercentage;
		}
		
		public function set bufferThresholdPercentage(value:Number):void {
			_bufferThresholdPercentage = value;
		}
		
		
		/**
		 * 
		 * Max amount of time in buffer
		 * 
		 * @param value
		 * 
		 */		
		public function set bufferFillTime(value:Number):void {
			_bufferFillTime = value;
		}
		public function get bufferFillTime():Number {
			return _bufferFillTime;
		}
		
		
		/**
		 * 
		 * Minimum amount of time in buffer which is needed to start playing the stream
		 *  
		 * @param value
		 * 
		 */
		public function get bufferPlaybackTime():Number {
			return _netStream.bufferTime;
		}		
		public function set bufferPlaybackTime(value:Number):void {
			_netStream.bufferTime = value;
		}
		
		/**
		 * 
		 * Time currently in the buffer
		 *  
		 * @return 
		 * 
		 */		
		public function get bufferLength():Number {
			return _netStream.bufferLength;
		}
		
		public function writeFLVTag(tag:FLVTag):void {
			var tagBytes:ByteArray = _tagBytes;
			
			tagBytes.clear();
			
			tagBytes.writeByte( (0 << 6) | (0 << 5) | 8 ); //1 byte reserved(2) | filter(1) | tagType(5)
			
			var dataSize:int = tag.payload.length + (tag.type == FLVTag.TYPE_AAC ? 2 : 1);
			
			write24Bit(tagBytes, dataSize); //dataSize is two bytes for AAC
			
			write24Bit(tagBytes, _timestamp & 0xFFFFFF); //timestamp in MS (lower 24 bits)
			
			tagBytes.writeByte((_timestamp >> 24) & 0xFF); //extended timestamp (upper 8 bits). So timestamp + extended timestamp = 32 bits
			
			write24Bit(tagBytes, 0); //streamID == 0
			
			tagBytes.writeByte( (tag.type << 4) | (tag.sampleRate << 2) | (tag.soundSize << 1) | tag.monoOrStereo); //1 bit <- 2 bit <- 4 bit
			
			if(tag.type == FLVTag.TYPE_AAC)
			{
				var aacPacket:int = tag.isAudioSpecificConfig ? 0 : 1; //0 == audio specific config as defined in http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio, 1 == AAC raw
				tagBytes.writeByte( aacPacket );
			}
			
			tagBytes.writeBytes(tag.payload); //write the actual data
			
			tagBytes.writeUnsignedInt(tagBytes.length); //write the size of the current tag
			
			_netStream.appendBytes(tagBytes);
			
			_timestamp += tag.duration;
		}
		
		public function beginFLV():void {
			_timestamp = 0;
			
			_netStream.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
			
			var header:ByteArray = new ByteArray();
			header.endian = Endian.BIG_ENDIAN; //multi bytes are in big endian
			
			header.writeByte(0x46); //1 byte F
			header.writeByte(0x4C); //1 byte L
			header.writeByte(0x56); //1 byte V
			header.writeByte(0x01); //1 byte version == 1
			header.writeByte((0 << 3) | (1 << 2) | (0 << 1) | 0); //1 byte reserved(5) | audio(1) | reserved(1) | video(1)
			header.writeUnsignedInt(9); //4 bytes length of header (9)
			
			header.writeUnsignedInt(0); //prev tag size
			
			_netStream.appendBytes( header );
		}
		
		protected function reset():void {
			_timestamp = 0;
			_tagBytes.clear();
		}
		
		protected function write24Bit(output:ByteArray, num:int):void {	
			for(var i:int=2;i >= 0;i--)
				output.writeByte( (num >> (i * 8)) & 0xff );
		}
	}
}