#name "CoEditor"
#author "sound_please"
#category "Map Editor"
#version "0.1.0"
#min_game_version "2021-01-01"

string server = "http://localhost:8180";
string session_id = "";
int refresh_interval = 10;
bool allow_ghost_blocks = false;
bool aggressive_removal = true; 
int log_level = 2;
int block_index = 0;
string player = Text::Format("%06X", Math::Rand(0,0xffffff));

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
    int BlockIndex;

    BlockData()
    {

    }

    BlockData(Json::Value block_json)
    {
        BlockIndex = block_json[2];
        Name = wstring(block_json[3]);
        Dir = block_json[4];
        State = BlockState(int(block_json[9]));
        Coord.x = block_json[5];
        Coord.y = block_json[6];
        Coord.z = block_json[7];
        FreeBlock = int(block_json[8]) == 1;
    }

    BlockData(CGameCtnBlock@ gameBlock)
    {
        Id = gameBlock.Id.Value;
        Name = gameBlock.BlockModel.Name;
        Dir = gameBlock.Dir;
        State = BlockState::Default;
        BlockIndex = -1;

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
        pos.x = int(Coord.x);
        pos.y = int(Coord.y);
        pos.z = int(Coord.z);
        CGameEditorPluginMap::ECardinalDirections direction = CGameEditorPluginMap::ECardinalDirections(Dir);

        if(!pluginMap.CanPlaceBlock(model, pos, direction, false, 0)){
            log("Block placement failed, (outside build limit or intersecting) at " + pos.ToString(), 2);
            if(!allow_ghost_blocks) {
                log("Ghost block placement not allowed", 2);
                return false;
            }
            if(!pluginMap.CanPlaceGhostBlock(model, pos, direction)){
                log("Ghost block placement failed at " + pos.ToString(), 2);
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
        pos.x = int(Coord.x);
        pos.y = int(Coord.y);
        pos.z = int(Coord.z);
        CGameEditorPluginMap::ECardinalDirections direction = CGameEditorPluginMap::ECardinalDirections(Dir);

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
		v.Add(Json::Value(Name));
		v.Add(Json::Value(Dir));
		v.Add(Json::Value(Coord.x));
		v.Add(Json::Value(Coord.y));
		v.Add(Json::Value(Coord.z));
		v.Add(Json::Value(FreeBlock));
		v.Add(Json::Value(State));
		
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

void log(string[] a, int level = 2) {
    if(level <= log_level) {
        string str = "";
        int len = a.Length;
        for(int i = 0; i < len; i++) {
            str += a[i] + ", ";
        }
        print("Array: [" + str + "]");
    }
}

void log(BlockData[] a)
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
    if(session_id == ""){
        return;
    }
    int len = a.Length;
    Json::Value post_data = Json::Object();

    // fill the Json Object with data we want to send to the server
    post_data['player'] = Json::Value(player);
    post_data['blocks'] = Json::Array();
    for(int i = 0; i < len; i++) {
		post_data['blocks'].Add(a[i].toJson());
    }
	
    string json_string = Json::Write(post_data);
    Net::HttpRequest@ request = Net::HttpPost(server + "/blocks/" + session_id + "/" + block_index, json_string, "application/json");

	while(!request.Finished()){
		sleep(100);
	}

    // Reading the response from the server

    Json::Value response = Json::Parse(request.String());
    if(!response['success']) {
        log(request.Url);
        log(request.String());
        return;
    }
    int blockCount = response['blocks'].get_Length();
    log("Received " + blockCount + " changed blocks:");
    BlockData[] newBlockData;
    for(int i = 0; i < blockCount; i++) {
        BlockData new = BlockData(response['blocks'][i]);
        if(new.BlockIndex > block_index) {
            block_index = new.BlockIndex;
        }
        newBlockData.InsertLast(new);
    }
    removeAndPlace(newBlockData);
}

void RenderMenu()
{
    UI::InputText("Player", player, 0x4000);
    UI::InputText("Block Number", Text::Format('%d',block_index), 0x4000);
    server = UI::InputText("Server Address", server);
    session_id = UI::InputText("Session", session_id, 0x8000);
    refresh_interval = UI::SliderInt("Interval", refresh_interval, 1, 30);
    log_level = UI::SliderInt("Log Level", log_level, 0, 2);
    allow_ghost_blocks = UI::Checkbox("Allow Ghost Blocks", allow_ghost_blocks);
    aggressive_removal = UI::Checkbox("Aggressive Removal", aggressive_removal);
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
        doMainLoop(oldBlocks, newBlocks);
        sleep(1000 * refresh_interval);
    }
}

bool doMainLoop(BlockData[] &oldBlocks, BlockData[] &newBlocks)
{
    if((cast<CGameCtnEditorFree>(GetApp().Editor)) is null) {
        // Not in Editor, we keep waiting
        return false;
    }
    CGameEditorPluginMapMapType@ pluginMap = cast<CGameCtnEditorCommon>(GetApp().Editor).PluginMapType;
    if(pluginMap.IsValidating || pluginMap.IsTesting) {
        // we don't change the map while driving
        return false;
    }

    newBlocks = getBlocks();
    if(oldBlocks.Length > 0 && newBlocks.Length > 0) {
        log("Scanning for changes...", 1);
        BlockData[] diff = blockDiff(oldBlocks, newBlocks);
        log(diff);
        send(diff);
    } else {
        log("Scanning blocks for the first time...", 1);
    }
    oldBlocks = getBlocks();

    return true;
}