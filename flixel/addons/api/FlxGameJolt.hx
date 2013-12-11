package flixel.addons.api;

import flash.display.Loader;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.URLRequestMethod;
import haxe.crypto.Md5;
import haxe.crypto.Sha1;
import flixel.FlxG;

#if flash
import flash.Lib;
#end

/**
 * Similar to FlxKongregate, this allows access to the GameJolt API. Based on the AS3 version by SumYungGai. Will always return Map<String,String> to callback functions.
 * 
 * @see 	http://gamejolt.com/community/forums/topics/as3-trophy-api/305/
 * @see 	http://gamejolt.com/api/doc/game/
 * @author 	SumYungGai
 * @author 	Steve Richey (STVR)
 * 
 * Usage:
 * Note: Do NOT store you private key as an unobfuscated string! One method is to save it as a text file called "myKey.privatekey" and add "*.privatekey" to your ignore list for version control (.gitignore for git, global-ignores in your config file for svn, .hgignore for Mercurial). Then:
	 * Below your import statements, add @:file("myKey.privatekey") class MyKey extends ByteArray { } to embed that file's data as a ByteArray.
	 * If your game is embedded as Flash on GameJolt's site, or run via Quick Play, you do not need to get the user name and token; this will be done automatically.
	 * Otherwise, you will need to retrieve the user name and token (possibly via an input box prompt).
	 * Then, verify this data via the following method:
		 * var bytearray = new MyKey(); // This will load your private key data as a ByteArray.
		 * var keystring = bytearray.readUTFBytes( bytearray.length ); // This converts the ByteArray to a string.
		 * var gameid = 1; // Replace "1" with your game ID, visible if you go to http://gamejolt.com/dashboard/ -> Click on your game under "Manage Games" -> Click on "Achievements" in the menu.
		 * FlxGameJolt.init( gameid, keystring ); // Use this if your game is embedded as Flash on GameJolt's site, or run via Quick Play. If 
 */
class FlxGameJolt
{
	/**
	 * The hash type to be used for private key encryption. Set to FlxGameJolt.HASH_MD5 or FlxGameJolt.HASH_SHA1. Default is MD5. See http://gamejolt.com/api/doc/game/ section "Signature".
	 */
	public static var hashType:Int = HASH_MD5;
	
	/**
	 * Whether or not the API has been fully initialized by passing game id, private key, and authenticating user name and token.
	 */
	public static var initialized(get, null):Bool;
	
	private static function get_initialized():Bool
	{
		return _initialized;
	}
	
	/**
	 * Hash types for the cryptography function. Use this or HASH_SHA1 for encryptURL(). MD5 is used by default.
	 */
	inline public static var HASH_MD5:Int = 0;
	
	/**
	 * Hash types for the cryptography function. Use this or HASH_MD5 for encryptURL(). MD5 is used by default.
	 */
	inline public static var HASH_SHA1:Int = 1;
	
	/**
	 * Trophy data return type, will return only non-unlocked trophies. As an alternative, can just pass in the ID of the trophy to see if it's unlocked.
	 */
	inline public static var TROPHIES_MISSING:Int = -1;
	
	/**
	 * Trophy data return type, will return only unlocked trophies. As an alternative, can just pass in the ID of the trophy to see if it's unlocked.
	 */
	inline public static var TROPHIES_ACHIEVED:Int = -2;
	
	/**
	 * Internal storage for a callback function, used when the URLLoader is complete.
	 */
	private static var _callBack:Dynamic;
	
	/**
	 * Internal storage for this game's ID.
	 */
	private static var _gameID:Int = 0;
	
	/**
	 * Internal storage for this game's private key. Do NOT store your private key as a string literal in your game! This can be found at http://gamejolt.com/dashboard/developer/games/achievements/GAME_ID/ where GAME_ID is your unique game ID number.
	 */
	private static var _privateKey:String = "";
	
	/**
	 * Internal storage for this user's username. Can be retrieved automatically if Flash or QuickPlay.
	 */
	private static var _userName:String;
	
	/**
	 * Internal storage for this user's token. Can be retrieved automatically if Flash or QuickPlay.
	 */
	private static var _userToken:String;
	
	/**
	 * Internal storage for the most common URL elements: the gameID, user name, and user token.
	 */
	private static var _idURL:String;
	
	/**
	 * Set to true once game ID, user name, user token have been set and user name and token has been verified.
	 */
	private static var _initialized:Bool = false;
	
	/**
	 * Internal variable that simply remembers if we're currently trying to authenticate user data.
	 */
	private static var _verifyAuth:Bool = false;
	
	/**
	 * Internal tracker for getting bitmapdata for a trophy image.
	 */
	private static var _getImage:Bool = false;
	
	/**
	 * Various common strings required by the API's HTTP values.
	 */
	inline private static var URL_API:String = "http://gamejolt.com/api/game/v1/";
	inline private static var RETURN_TYPE:String = "?format=keypair";
	inline private static var URL_GAME_ID:String = "&game_id=";
	inline private static var URL_USER_NAME:String = "&username=";
	inline private static var URL_USER_TOKEN:String = "&user_token=";
	
	/**
	 * Initialize this class by storing the GameID and private key. You must call this function first. To enable user-specific functions, call authUser() afterward.
	 * 
	 * @param	GameID		The unique game ID associated with this game on GameJolt. You must create a game profile on GameJolt to get this number.	
	 * @param	PrivateKey	Your private key. You must have a developer account on GameJolt to have this number. Do NOT store this as plaintext in your game!
	 * @param	AutoAuth	Call authUser after init() has run to authenticate user data.
	 * @param 	?UserName	The username to authenticate, if AutoAuth is true. If you set AutoAuth to true but don't put a value here, FlxGameJolt will attempt to get the user data automatically, which will only work for Flash embedded on GameJolt, or desktop games run via Quick Play.
	 * @param 	?UserToken	The user token to authenticate, if AutoAuth is true. If you set AutoAuth to true but don't put a value here, FlxGameJolt will attempt to get the user data automatically, which will only work for Flash embedded on GameJolt, or desktop games run via Quick Play.
	 * @param 	?Callback 	An optional callback function, which is only used if AutoAuth is set to true. Will return true if authentication was successful, false otherwise.
	 */
	public static function init( GameID:Int, PrivateKey:String, AutoAuth:Bool = false, ?UserName:String, ?UserToken:String, ?Callback:Dynamic ):Void
	{
		_gameID = GameID;
		_privateKey = PrivateKey;
		
		if ( AutoAuth ) {
			authUser( UserName, UserToken, Callback );
		}
	}
	
	/**
	 * Fetch user data. Pass UserID to get user name, pass UserName to get UserID, or pass multiple UserIDs to get multiple usernames.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/users/fetch/
	 * @param	?UserID		An integer user ID value. If this is passed, UserName and UserIDs are ignored. Pass 0 to ignore.
	 * @param	?UserName	A string user name. If this is passed, UserIDs is ignored. Pass "" or nothing to ignore.
	 * @param	?UserIDs	An array of integers representing user IDs. Pass [] or nothing to ignore.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function fetchUser( ?UserID:Int, ?UserName:String, ?UserIDs:Array<Int>, ?Callback:Dynamic ):Void
	{
		var tempURL:String = URL_API + "users/" + RETURN_TYPE;
		
		if ( UserID != null && UserID != 0 ) {
			tempURL += "&user_id=" + Std.string( UserID );
		} else if ( UserName != null && UserName != "" ) {
			tempURL += "&username=" + UserName;
		} else if ( UserIDs != null && UserIDs != [] ) {
			tempURL += "&user_id=";
			
			for ( id in UserIDs ) {
				tempURL += Std.string( id ) + ",";
			}
			
			tempURL = tempURL.substr(0, tempURL.length - 1);
		} else {
			return;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Verify user data. Must be called before any user-specific functions, and after init(). Will set initialized to true if successful.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/users/auth/
	 * @param	?UserName	A user name. Leave null to automatically pull user data (only works for embedded Flash on GameJolt or Quick Play).
	 * @param	?UserToken	A user token. Players enter this instead of a password to enable highscores, trophies, etc. Leave null to automatically pull user data (only works for embedded Flash on GameJolt or Quick Play).
	 * @param	?Callback	An optional callback function. Will return true if authentication was successful, false otherwise.
	 */
	public static function authUser( ?UserName:String, ?UserToken:String, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		
		if ( UserName == null || UserToken == null ) {
			#if desktop
			for ( arg in Sys.args() ) {
				var argArray = arg.split( "=" );
				
				if ( argArray[0] == "gjapi_username" ) {
					_userName = argArray[1];
				}
				
				if ( argArray[0] == "gjapi_token" ) {
					_userToken = argArray[1];
				}
			}
			#elseif flash
			var parameters = Lib.current.loaderInfo.parameters;
			
			if ( parameters.gjapi_username != null ) {
				_userName = parameters.gjapi_username;
			}
			
			if ( parameters.gjapi_token != null ) {
				_userToken = parameters.gjapi_token;
			}
			#end
		} else {
			_userName = UserName;
			_userToken = UserToken;
		}
		
		// Only send initialization request to GameJolt if user name and token were found or passed.
		
		if ( _userName != null && _userToken != null ) {
			_idURL = URL_GAME_ID + _gameID + URL_USER_NAME + _userName + URL_USER_TOKEN + _userToken;
			_verifyAuth = true;
			sendLoaderRequest( URL_API + "users/auth/" + RETURN_TYPE + _idURL, Callback );
		} else {
			#if debug
			FlxG.log.warn( "FlxGameJolt: Unable to access user name or token, and no user name or token was passed." );
			#end
		}
	}
	
	/**
	 * Begin a new session. Sessions that are not pinged at most every 120 seconds will be closed. Requires user authentication.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/sessions/open/
	 * @param 	?Callback 	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function openSession( ?Callback:Dynamic ):Void
	{
		if ( !authenticated ) return;
		
		sendLoaderRequest( URL_API + "sessions/open/" + RETURN_TYPE + _idURL, Callback );
	}
	
	/**
	 * Ping the current session. The API states that a session will be closed after 120 seconds without a ping, and recommends pinging every 30 seconds or so. Requires user authentication.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/sessions/ping/
	 * @param	Active		Leave true to set the session to active, or set to false to set the session to idle.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function pingSession( Active:Bool = true, ?Callback:Dynamic ):Void
	{
		if ( !authenticated ) return;
		
		var tempURL = URL_API + "sessions/ping/" + RETURN_TYPE + _idURL + "&active=";
		
		if ( Active ) {
			tempURL += "active";
		} else {
			tempURL += "idle";
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Close the current session. Requires user author authentication.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/sessions/close/
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function closeSession( ?Callback:Dynamic ):Void
	{
		if ( !authenticated ) return;
		
		sendLoaderRequest( URL_API + "sessions/close/" + RETURN_TYPE + _idURL, Callback );
	}
	
	/**
	 * Retrieve trophy data. Requires user authentication.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/trophies/fetch/
	 * @param	DataType	Pass FlxGameJolt.TROPHIES_MISSING or FlxGameJolt.TROPHIES_ACHIEVED to get the trophies this user is missing or already has, respectively.  Or, pass in a trophy ID # to see if this user has that trophy or not.  If unused or zero, will return all trophies.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function fetchTrophy( DataType:Int = 0, ?Callback:Dynamic ):Void
	{
		if ( !authenticated ) return;
		
		var tempURL:String = URL_API + "trophies/" + RETURN_TYPE + _idURL;
		
		switch( DataType ) {
			case 0:
				tempURL += "&achieved=";
			case TROPHIES_MISSING:
				tempURL += "&achieved=false";
			case TROPHIES_ACHIEVED:
				tempURL += "&achieved=true";
			default:
				tempURL += "&trophy_id=" + Std.string( DataType );
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Unlock a trophy for this user. Requires user authentication.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/trophies/add-achieved/
	 * @param	TrophyID	The unique ID number for this trophy. Can be seen at http://gamejolt.com/dashboard/developer/games/achievements/<Your Game ID>/ in the right-hand column.
	 * @param 	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function addTrophy( TrophyID:Int, ?Callback:Dynamic ):Void
	{
		if ( !authenticated ) return;
		
		sendLoaderRequest( URL_API + "trophies/add-achieved/" + RETURN_TYPE + _idURL + "&trophy_id=" + TrophyID, Callback );
	}
	
	/**
	 * Retrieve the high scores from this game's remote data. If not authenticated, leaving Limit null will still return the top ten scores. Requires initialization.
	 * 
	 * @see		http://gamejolt.com/api/doc/game/scores/fetch/
	 * @param	?Limit		The maximum number of scores to retrieve. Leave null to retrieve only this user's scores.
	 * @param	?CallBack	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function fetchScore( ?Limit:Int, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		
		var tempURL = URL_API + "scores/" + RETURN_TYPE;
		
		if ( !_initialized ) {
			if ( Limit == null ) {
				tempURL += "&limit=10";
			} else {
				tempURL += "&limit=" + Std.string( Limit );
			}
		} else if ( Limit != null ) {
			tempURL += "&limit=" + Std.string( Limit );
		} else {
			tempURL += _idURL;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Set a new high score, either globally or for this particular user. Requires game initialization. If user data is not authenticated, GuestName is required.
	 * 
	 * @see		http://gamejolt.com/api/doc/game/scores/add/
	 * @param	Score		A string representation of the score, such as "234 Jumps".
	 * @param	Sort		A numerical representation of the score, such as 234. Used for sorting of data.
	 * @param 	AllowGuest	Whether or not to allow guest scores. If true is passed, and user data is not present (i.e. authUser() was not successful), GuestName will be used if present. If false, the score will only be added if user data is authenticated.
	 * @param	?GuestName	The guest name to use, if AllowGuest is true. Ignored otherwise.
	 * @param	?ExtraData	Optional extra data associated with the score, which will NOT be visible on the site but can be retrieved by the API.
	 * @param 	?TableID	Optional: the ID of the table you'd lke to send data to. If null, score will be sent to the primary high score table.
	 * @param 	?Callback 	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function addScore( Score:String, Sort:Float, AllowGuest:Bool = false, ?GuestName:String, ?ExtraData:String, ?TableID:Int, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		
		if ( !authenticated && !AllowGuest ) return;
		
		var tempURL = URL_API + "scores/add/" + RETURN_TYPE + "&game_id=" + _gameID + "&score=" + Score + "&sort=" + Std.string( Sort );
		
		// If AllowGuest is true
		
		if ( AllowGuest && GuestName != null ) {
			tempURL += "&guest=" + GuestName;
		} else {
			tempURL += URL_USER_NAME + _userName + URL_USER_TOKEN + _userToken;
		}
		
		if ( ExtraData != null ) {
			tempURL += "&extra_data=" + ExtraData;
		}
		
		if ( TableID != null ) {
			tempURL += "&table_id=" + TableID;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Retrieve a list of high score tables for this game.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/scores/tables/
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function getTables( ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		
		sendLoaderRequest( URL_API + RETURN_TYPE + URL_GAME_ID + _gameID, Callback );
	}
	
	/**
	 * Get data from the remote data store.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/data-store/fetch/
	 * @param	Key			The key for the data to retrieve.
	 * @param	User		Whether or not to get the data associated with this user. True by default.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function fetchData( Key:String, User:Bool = true, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		if ( User && !authenticated ) return;
		
		var tempURL = URL_API + "data-store/" + RETURN_TYPE + "&key=" + Key;
		
		if ( User ) {
			tempURL += _idURL;
		} else {
			tempURL += URL_GAME_ID + _gameID;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Set data in the remote data store.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/data-store/set/
	 * @param	Key			The key for this data.
	 * @param	Value		The key value.
	 * @param	User		Whether or not to associate this with this user. True by default.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function setData( Key:String, Value:String, User:Bool = true, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		if ( User && !authenticated ) return;
		
		var tempURL = URL_API + "data-store/set/" + RETURN_TYPE + "&key=" + Key + "&data=" + Value;
		
		if ( User ) {
			tempURL += _idURL;
		} else {
			tempURL += URL_GAME_ID + _gameID;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Update data which is in the data store.
	 * 
	 * @see		http://gamejolt.com/api/doc/game/data-store/update/
	 * @param	Key			The key of the data you'd like to manipulate.
	 * @param	Operation	The type of operation. Acceptable values: "add", "subtract", "multiply", "divide", "append", "prepend". The former four are only valid on numerical values, the latter two only on strings.
	 * @param	Value		The value that you'd like to work with on the data store.
	 * @param	User		Whether or not to work with the data associated with this user.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function updateData( Key:String, Operation:String, Value:String, User:Bool = true, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		if ( User && !authenticated ) return;
		
		var tempURL = URL_API + "data-store/update/" + RETURN_TYPE + "&key=" + Key + "&operation=" + Operation + "&value=" + Value;
		
		if ( User ) {
			tempURL += _idURL;
		} else {
			tempURL += URL_GAME_ID + _gameID;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Remove data from the remote data store.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/data-store/remove/
	 * @param	Key			The key for the data to remove.
	 * @param	User		Whether or not to remove the data associated with this user. True by default.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function removeData( Key:String, User:Bool = true, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		if ( User && !authenticated ) return;
		
		var tempURL = URL_API + "data-store/remove/" + RETURN_TYPE + "&key=" + Key;
		
		if ( User ) {
			tempURL += _idURL;
		} else {
			tempURL += URL_GAME_ID + _gameID;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * Get all keys in the data store.
	 * 
	 * @see 	http://gamejolt.com/api/doc/game/data-store/get-keys/
	 * @param	User		Whether or not to get the keys associated with this user. True by default.
	 * @param	?Callback	An optional callback function. Will return a Map<String:String> whose keys and values are equivalent to the key-value pairs returned by GameJolt.
	 */
	public static function getAllKeys( User:Bool = true, ?Callback:Dynamic ):Void
	{
		if ( !gameInit ) return;
		if ( User && !authenticated ) return;
		
		var tempURL = URL_API + "data-store/get-keys/" + RETURN_TYPE;
		
		if ( User ) {
			tempURL += _idURL;
		} else {
			tempURL += URL_GAME_ID + _gameID;
		}
		
		sendLoaderRequest( tempURL, Callback );
	}
	
	/**
	 * A generic function to setup and send a URLRequest. All of the functions that interact with the API use this.
	 * 
	 * @param	URLString	The URL to send to. Usually formatted as the API url, section of the API (e.g. "trophies/") and then variables to pass (e.g. user name, trophy ID).
	 * @param	?Callback	A function to call when loading is done and data is parsed.
	 */
	private static function sendLoaderRequest( URLString:String, ?Callback:Dynamic ):Void
	{
		var request:URLRequest = new URLRequest( URLString + "&signature=" + encryptURL( URLString ) );
		request.method = URLRequestMethod.POST;
		
		if ( Callback != null ) {
			_callBack = Callback;
		}
		
		var loader = new URLLoader();
		loader.addEventListener( Event.COMPLETE, parseData );
		loader.load( request );
	}
	
	/**
	 * Called when the URLLoader has received data back. Will call _callBack() with the data received from GameJolt as Map<String,String> when done.
	 * 
	 * @param	The URLLoader complete event.
	 */
	private static function parseData( e:Event ):Void
	{
		if ( Std.string( e.currentTarget.data ) == "" ) {
			#if debug
			FlxG.log.warn( "FlxGameJolt received no data back. This is probably because one of the values it was passed is wrong." );
			#end
			
			return;
		}
		
		var returnMap:Map<String,String> = new Map<String,String>();
		var stringArray:Array<String> = Std.string( e.currentTarget.data ).split( "\r" );
		
		// this regex will remove line breaks down below
		var r:EReg = ~/[\r\n\t"]+/g;
		
		for ( string in stringArray ) {
			// remove quotes, line breaks via regex
			string = r.replace( string, "" );
			if ( string.length > 1 ) {
				var split:Int = string.indexOf( ":" );
				var temp:Array<String> = [ string.substring( 0, split ), string.substring( split + 1, string.length ) ];
				returnMap.set( temp[0], temp[1] );
			}
		}
		
		if ( _getImage ) {
			retrieveImage( returnMap );
			return;
		}
		
		if ( _callBack != null && !_verifyAuth ) {
			_callBack( returnMap );
		} else if ( _verifyAuth ) {
			verifyAuthentication( returnMap );
		}
	}
	
	/**
	 * Internal function to evaluate whether or not a user was successfully authenticated and store the result in _initialized. If authentication failed, the tentative user name and token are nulled.
	 * 
	 * @param	ReturnMap	The data received back from GameJolt. This should be {"success"="true"} if authenticated, or {"success"="false"} otherwise.
	 */
	private static function verifyAuthentication( ReturnMap:Map<String,String> ):Void
	{
		if ( ReturnMap.exists( "success" ) && ReturnMap.get( "success" ) == "true" ) {
			_initialized = true;
		} else {
			_userName = null;
			_userToken = null;
		}
		
		_verifyAuth = false;
		
		if ( _callBack != null ) {
			_callBack( _initialized );
		}
	}
	
	/**
	 * An easy-to-use function that returns the image associated with a trophy as BitmapData.
	 * 
	 * @param	ID			The ID of the trophy whose image you want to get.
	 * @param	?Callback	An optional callback function. Must take a BitmapData object as a parameter.
	 */
	public static function fetchTrophyImage( ID:Int, ?Callback:BitmapData -> Void ):Void
	{
		_getImage = true;
		fetchTrophy( ID, Callback );
	}
	
	private static function retrieveImage( TrophyMap:Map<String,String> ):Void
	{
		if ( TrophyMap.exists( "image_url" ) ) {
			var request:URLRequest = new URLRequest( TrophyMap.get( "image_url" ) );
			var loader = new Loader();
			loader.contentLoaderInfo.addEventListener( Event.COMPLETE, returnImage );
			loader.load( request );
		} else {
			#if debug
			FlxG.log.warn( "FlxGameJolt: Failed to load trophy image" );
			#end
		}
	}
	
	private static function returnImage( e:Event ):Void
	{
		if ( _callBack != null ) {
			_callBack( e.currentTarget.content.bitmapData );
		}
		
		_getImage = false;
	}
	
	/**
	 * Generate an MD5 or SHA1 hash signature, required by the API to verify game data is valid. Passed to the API as "&signature=".
	 * 
	 * @see		http://gamejolt.com/api/doc/game/ 	Section titled "Signature".
	 * @param	Url		The URL to encrypt. This and the private key form the string which is encoded.
	 * @return	An encoded MD5 or SHA1 hash. By default, will be MD5; set FlxGameJolt.hashType = FlxGameJolt.HASH_SHA1 to use SHA1 encoding.
	 */
	private static function encryptURL( Url:String ):String
	{
		if ( hashType == HASH_SHA1 ) {
			return Sha1.encode( Url + _privateKey );
		} else {
			return Md5.encode( Url + _privateKey );
		}
	}
	
	/**
	 * Internal method to verify that init() has been called on this class. Called before running functions that require game ID or private key but not user data.
	 * 
	 * @return	True if game ID is set, false otherwise.
	 */
	private static var gameInit(get, null):Bool;
	
	private static function get_gameInit():Bool {
		if ( _gameID == 0 || _privateKey == "" ) {
			#if debug
			FlxG.log.warn( "FlxGameJolt: You must run init() before you can do this. Game ID is " + _gameID + " and the key is " + _privateKey + "." );
			#end
			
			return false;
		} else {
			return true;
		}
	}
	
	/**
	 * Internal method to verify that this user (and game) have been authenticated. Called before running functions which require authentication.
	 * 
	 * @return 	True if authenticated, false otherwise.
	 */
	private static var authenticated(get, null):Bool;
	
	private static function get_authenticated():Bool {
		if ( !gameInit ) return false;
		
		if ( !_initialized ) {
			#if debug
			FlxG.log.warn( "FlxGameJolt: You must authenticate user before you can do this." );
			#end
			
			return false;
		} else {
			return true;
		}
	}
	
	/**
	 * The user's GameJolt user name. Only works if you've called authUser() and/or init(), otherwise will return "No user".
	 */
	public static var username(get, null):String;
	
	private static function get_username():String
	{
		if ( !_initialized || _userName == null || _userName == "" ) {
			return "No user";
		} else {
			return _userName;
		}
	}
	
	/**
	 * An alternative to running authUser() and hoping for the best; this will tell you if your game was run via Quick Play, and user name and token is available. Does NOT authenticate the user data!
	 *
	 * @return	True if this was run via Quick Play with user name and token available, false otherwise.
	 */
	public static var isQuickPlay(get, null):Bool;
	
	private static function get_isQuickPlay():Bool
	{
		#if !desktop
		return false;
		#else
		var argmap:Map < String, String > = new Map < String, String > { };
		
		for ( arg in Sys.args() ) {
			var argArray = arg.split( "=" );
			argmap.set( argArray[0], argArray[1] );
		}
		
		if ( argmap.exists( "gjapi_username" ) && argmap.exists( "gjapi_token" ) ) {
			return true;
		} else {
			return false;
		}
		#end
	}
	
	/**
	 * An alternative to running authUser() and hoping for the best; this will tell you if your game was run as an embedded Flash on GameJolt that has user name and token data already. Does NOT authenticate the user data!
	 *
	 * @return	True if it's an embedded SWF with user name and token available, false otherwise.
	 */
	public static var isEmbeddedFlash(get, null):Bool;
	
	private static function get_isEmbeddedFlash():Bool
	{
		#if !flash
		return false;
		#else
		var parameters = Lib.current.loaderInfo.parameters;
		
		if ( parameters.gjapi_username != null && parameters.gjapi_token != null ) {
			return true;
		} else {
			return false;
		}
		#end
	}
}