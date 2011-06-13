package nl.remcokrams.advertising
{
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	
	/**
	 *	Created by remcokrams
	 *	Jun 5, 2011	
	 **/
	
	public class AWSProductAdvertisingApi
	{
		public static const SERVICE:String = "http://www.remcokrams.nl/amazonSearch/amazonSearch.php";
		
		public function AWSProductAdvertisingApi()
		{
		}
		
		public function itemSearch(keywords:String, searchIndex:String="All", responseGroup:Array=null):AWSQueryResult {
			var vars:URLVariables = new URLVariables();
			vars.Operation = "ItemSearch";
			vars.Keywords = keywords;
			vars.SearchIndex = searchIndex;
			vars.ResponseGroup = responseGroup.join(",");
			
			var request:URLRequest = new URLRequest(SERVICE);
			request.data = vars;
			
			var loader:URLLoader = new URLLoader( request );
			return new AWSQueryResult("itemSearch", loader);
		}
	}
}