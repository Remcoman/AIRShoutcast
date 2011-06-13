package nl.remcokrams.shoutcast
{
	
	/**
	 *	Created by remcokrams
	 *	May 13, 2011	
	 **/
	
	public class ShoutcastPlayerPhase
	{
		public static const DISCONNECTED:int 		   = 0;
		public static const CONNECTING:int 		 	   = 1;
		public static const CONNECTED_TO_STREAM:int    = 2;
		public static const BUFFERING_START:int  	   = 4;
		public static const BUFFERING_END:int  	 	   = 5;
		public static const ERROR:int  	 	 	 	   = 6;
	}
}