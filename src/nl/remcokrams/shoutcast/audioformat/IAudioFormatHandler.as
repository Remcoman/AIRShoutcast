package nl.remcokrams.shoutcast.audioformat
{
	import flash.net.URLStream;
	import flash.utils.IDataInput;
	
	import nl.remcokrams.shoutcast.FLVTag;
	import nl.remcokrams.shoutcast.StreamInfo;

	public interface IAudioFormatHandler
	{
		/**
		 *  
		 * @return a list of compatible content types (should be unique)
		 * 
		 */		
		function get compatibleContentTypes():Vector.<String>;
		
		/**
		 *  
		 * Use this method to initialize your handler and check the given SteamInfo for incompatibilities
		 * 
		 * @param info the info that is currently available for the stream
		 * @return true if succeeded or false if otherwise
		 * 
		 */		
		function init(info:StreamInfo):Boolean;
		
		/**
		 *  
		 * Implement your format handling code here
		 * 
		 * @param stream read from this stream
		 * @param flvTag write your data (payload, samplerate etc) to this flvtag
		 * @param readMax the max number of bytes you should read. Never read more than this number to avoid problems with reading the metadata
		 * @return the actual number of bytes you read
		 * 
		 */		
		function readMore(stream:IDataInput, flvTag:FLVTag, readMax:int):int;
		
		/**
		 *
		 * Use this method to clear bytearrays and reset states. 
		 * 
		 */		
		function reset():void;
	}
}