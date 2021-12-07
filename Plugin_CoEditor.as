#name "CoEditor"
#author "sound_please"
#category "Map Editor"
#min_game_version "2021-01-01"

string url = "http://tmcoedit.duckdns.org/index.php";
int refresh_interval = 10;
bool allow_ghost_blocks = true;
bool aggressive_removal = true; 
int log_level = 2;

/* TODO 
 - Place all Blocks in Air Mode or place AirBlocks in Air Mode and ignore pillars
 - items
 - Ghost Blocks
 - FreeBlocks

*/
enum BlockState {
    Default,
    Added,
    Deleted,
}

class BlockData
{
    uint Id;
    wstring Name;
    uint Dir;
    vec3 Coord;
    bool FreeBlock;
    BlockState State;

    BlockData()
    {

    }

    BlockData(CGameCtnBlock@ gameBlock)
    {
        Id = gameBlock.Id.Value;
        Name = gameBlock.BlockModel.Name;
        Dir = gameBlock.Dir;
        State = BlockState::Default;

        if(gameBlock.CoordX == 4294967295 && gameBlock.CoordZ == 4294967295){
            // free block, thanks @Beu
            FreeBlock = true;
            vec3 pos = Dev::GetOffsetVec3(gameBlock, 0x6c);
            Coord.x = pos.x / 32;
            Coord.y = (pos.y / 8) + 8;
            Coord.z = pos.z / 32;
        }
        else {
            FreeBlock = false;
            Coord.x = gameBlock.Coord.x;
            Coord.y = gameBlock.Coord.y;
            Coord.z = gameBlock.Coord.z;
        }
    }

    bool place(CGameEditorPluginMapMapType@ pluginMap)
    {
        if(FreeBlock) {
            // how to place free blocks? please explain
            log("Cannot place Free Block!", 2);
            return false;
        }
        CGameCtnBlockInfo@ model = pluginMap.GetBlockModelFromName(Name);

        int3 pos;
        pos.x = 47 - int(Coord.x);
        pos.y = int(Coord.y);
        pos.z = 47 - int(Coord.z);
        CGameEditorPluginMap::ECardinalDirections direction = CGameEditorPluginMap::ECardinalDirections((Dir+2) % 4);

        if(!pluginMap.CanPlaceBlock(model, pos, direction, false, 0)){
            log("Block placement failed, (outside build limit or intersecting) at " + pos.ToString(), 2);
            if(!pluginMap.CanPlaceGhostBlock(model, pos, direction)){
                log("Ghost block placement failed at " + pos.ToString(), 2);
                return false;
            }
            if(!allow_ghost_blocks) {
                log("Ghost block placement not allowed", 2);
                return false;
            }
            log("Placing ghost block at " + pos.ToString(), 2);
            return pluginMap.PlaceGhostBlock(model, pos, direction);
        }
        log("Placing block at " + pos.ToString() + (pluginMap.EnableAirMapping ? " Air" : " NoAir"), 2);
        return pluginMap.PlaceBlock(model, pos, direction);
    }

    bool remove(CGameEditorPluginMapMapType@ pluginMap)
    {
        if(FreeBlock) {
            // how to place free blocks? please explain
            log("Cannot remove Free Block!", 2);
            return false;
        }
        CGameCtnBlockInfo@ model = pluginMap.GetBlockModelFromName(Name);

        int3 pos;
        pos.x = 47 - int(Coord.x);
        pos.y = int(Coord.y);
        pos.z = 47 - int(Coord.z);
        CGameEditorPluginMap::ECardinalDirections direction = CGameEditorPluginMap::ECardinalDirections((Dir+2) % 4);

        if(pluginMap.RemoveBlockSafe(model, pos, direction)){
            log("Removed block at " + pos.ToString(), 2);
            return true;
        }
        else 
        if(aggressive_removal && pluginMap.RemoveBlock(pos)){
            log("Removed block aggressively at " + pos.ToString(), 2);
            return true;
        } 
        else {
            log("Could not remove block at " + pos.ToString(), 2);
            return false;
        }
    }
	
	Json::Value toJson()
	{
		Json::Value v = Json::Array();
		Json::Value p = Json::Array();
		p.Add(Json::Value(Coord.x));
		p.Add(Json::Value(Coord.y));
		p.Add(Json::Value(Coord.z));
		v.Add(Json::Value(Id));
		v.Add(Json::Value(Name));
		v.Add(p);
		v.Add(Json::Value(Dir));
		v.Add(Json::Value(State));
		v.Add(Json::Value(FreeBlock));
		
		return v;
	}
}

BlockData[] getBlocks()
{
    BlockData[] blockData;
    MwFastBuffer<CGameCtnBlock@> blocks = cast<CGameCtnEditorCommon>(GetApp().Editor).Challenge.Blocks;
    uint len = blocks.Length;
    for(uint i = 0; i < len; i++) {
        BlockData bd = BlockData(blocks[i]);
        blockData.InsertLast(bd);
    }

    return blockData;
}

BlockData[] blockDiff(BlockData[] oldBlocks, BlockData[] newBlocks)
{
    BlockData[] diff;

    int oldMax = oldBlocks.Length;
    int newMax = newBlocks.Length;
    int j = 0;
    for(int i = 0; i < oldMax; i++) {
        if(j < newMax && oldBlocks[i].Id == newBlocks[j].Id){
            j++;
        }
        else {
            // Block was deleted since last update
            oldBlocks[i].State = BlockState::Deleted;
            diff.InsertLast(oldBlocks[i]);
        }
    }

    for(j; j < newMax; j++){
        // Block was added since last update
        newBlocks[j].State = BlockState::Added;
        diff.InsertLast(newBlocks[j]);
    }

    return diff;
}

void printArray(BlockData[] a)
{
    int len = a.Length;
    if(len == 0) {
        return;
    }
    
    log("=> " + len + " blocks have changed", 1);
    for(int i = 0; i < len; i++) {
        string s = a[i].State == 1 ? "+" : (a[i].State == 2 ? "-" : "°");
        log("  " + s + " " + a[i].Name + ": " + a[i].Coord.ToString(), 2);
    }
}

void send(BlockData[] a)
{
    int len = a.Length;
	Json::Value v = Json::Array();
  
    for(int i = 0; i < len; i++) {
		v.Add(a[i].toJson());
    }
	
    string json_data = Json::Write(v);
    Net::HttpRequest@ request = Net::HttpPost(url, json_data, "text/plain");
	while(!request.Finished()){
		sleep(100);
	}
	log(request.Url);
	log(request.ResponseCode());
	log(request.ResponseHeaders());
	log(request.String());
}

void removeAndPlace(BlockData[] a)
{
    int len = a.Length;
    if(len == 0) {
        return;
    }
    CGameEditorPluginMapMapType@ pluginMap = cast<CGameCtnEditorCommon>(GetApp().Editor).PluginMapType;

    pluginMap.EnableAirMapping = true;
    
    for(int i = 0; i < len; i++) {
        if(a[i].State == BlockState::Added){
            a[i].place(pluginMap);
        }
        if(a[i].State == BlockState::Deleted){
            a[i].remove(pluginMap);
        }
        
    }
}

void log(string text, int level = 2) {
    if(level <= log_level) {
        print(text);
    }
}

void log(int text, int level = 2) {
    if(level <= log_level) {
        print(text);
    }
}

void log(dictionary dict, int level = 2) {
	if(level <= log_level) {
		string[]@ keys = dict.GetKeys();
		int len = keys.Length;
		for(int i = 0; i < len; i++) {
			print(keys[i] + " ==> " + string(dict[keys[i]]));
		}
	}
}

void RenderMenu()
{
    url = UI::InputText("Server URL", url);
    refresh_interval = UI::SliderInt("Interval", refresh_interval, 1, 30);
    log_level = UI::SliderInt("Log Level", log_level, 0, 2);
    allow_ghost_blocks = UI::Checkbox("Allow Ghost Blocks", allow_ghost_blocks);
    aggressive_removal = UI::Checkbox("Aggressive Removal", allow_ghost_blocks);
}

void Main()
{    
    if (OpenplanetHasFullPermissions()){
        log("You have Club access!", 0);
    } 
    else if (OpenplanetHasPaidPermissions()) {
        log("You have Standard access!", 0);
    }
    else {
        log("You have Starter access!", 0);
    }

    BlockData[] oldBlocks;
    BlockData[] newBlocks;

    while(true) {
        if((cast<CGameCtnEditorFree>(GetApp().Editor)) is null) {
            log("Not in Editor.", 2);
        }
        else {
            newBlocks = getBlocks();
            if(oldBlocks.Length > 0 && newBlocks.Length > 0) {
                BlockData[] diff = blockDiff(oldBlocks, newBlocks);
                printArray(diff);
                send(diff);
            } else {
                log("Scanning blocks...", 1);
            }
            oldBlocks = getBlocks();
        }
        
        sleep(1000 * refresh_interval);
    }
}