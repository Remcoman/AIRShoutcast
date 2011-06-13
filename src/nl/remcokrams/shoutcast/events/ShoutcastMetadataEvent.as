package nl.remcokrams.shoutcast.events
{
	import flash.events.Event;
	
	
	/**
	 *	Created by remcokrams
	 *	Apr 25, 2011	
	 **/
	
	public class ShoutcastMetadataEvent extends Event
	{
		public static const METADATA_AVAILABLE:String = "metadata_available";
		
		private static const MATCH_FIELD:RegExp = /([\w]+)\='(.*?)';/g;
		
		protected var _metadataRaw:String;
		protected var _metadataObj:Object;
		
		public function ShoutcastMetadataEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, metadata:String=null)
		{
			super(type, bubbles, cancelable);
			_metadataRaw = metadata;
		}
		
		public function get metadata():Object {
			if(!_metadataObj)
			{
				var obj:Object = {}, match:Object;
				MATCH_FIELD.lastIndex = 0;
				while( (match = MATCH_FIELD.exec(_metadataRaw)) != null )
					obj[ match[1] ] = match[2];
				_metadataObj = obj;
			}
			return _metadataObj;
		} 
		
		public function get rawMetadata():String {
			return _metadataRaw;
		}
		
		override public function clone():Event {
			return new ShoutcastMetadataEvent(type, bubbles, cancelable, _metadataRaw);
		}
	}
}