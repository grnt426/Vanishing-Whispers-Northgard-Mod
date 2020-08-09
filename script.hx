/*
 * ================================================
 * 			Drage Ander Island
 * 			Dragon Spirits Island
 *
 * The player must discover the secrets of the island before the island is consumed by spirits.
 * What choices will you make? Can you discover all three endings?
 * ================================================
 */

/**
 *  The human player playing this mod :)
 */
var human:Player;

var VERSION = "1.3";

DEBUG = {
	SKIP_STUDYING: false,
	MESSAGES: false,
	SPIRITS_FAST: false,
	BAD:false, // setup debug for bad ending
	NEU:false, // setup debug for neutral ending
	GOO:false, // setup debug for good ending
	ALL_EXPLORED:false,

	TIME_INDEX:0,

	QUICK_BUTTON:true,
	QUICK_BUTTON_INDEX:0,
}

var START_ZONE_ID: Int = 65;
var MYSTERY_ZONE_ID: Int = 8;
var GRAVEYARD_ZONE_ID: Int = 72;
var PORT_ZONE_ID: Int = 39;
var PORT_LAUNCH_ZONE_ID: Int = 20;
var LORE_CIRCLE_ZONE_IDS = [41, 45];
var KOBOLD_HOME_TILE_ID: Int = 53;
var STARTER_CARVED_STONE_TILE_ID: Int = 76;

/**
 * These zones will not be captured by the spirits, but they can attack them
 * 66 - Farm west of start
 * 60 - Forest, east of start
 * 53 - Kobold home tile
 * 74 - Jotunn camp
 *
 * All other zones are capturable by the spirits, and once captured, lost forever.
 */
var SAFE_ZONES = [START_ZONE_ID, 66, 60, 53, 74];

/**
 * These zones are where the spirits will launch their attacks. Once captured,
 * they will start trying to claim neighbors, so this list will grow over time.
 *
 * 30 - North-east, iron/runestone
 * 63 - Ruins, north west
 * 80 - Ruins south of start
 * 84 - farm south-west of start
 * 85 - Southern most tile
 * 87 - Geyser, east
 * 90 - Wolf den, west

 */
var INVASION_ZONES = [30, 63, 80, 84, 85, 87, 90];

/**
 * These zones will be added after year 3, as they are harder to get to or important.
 *
 * 25 - Stone deposit
 * 37 - Northern forest, leading to port
 * 38 - Thor's Wrath
 * 41 - Northern circle of stones
 * 45 - Southern circle of stones
 * 50 - empty plain, leading to port
 * 72 - Graveyard
 */
var INVASION_SECOND_STARTING_WAVE_ZONES = [25, 37, 38, 41, 45, 50, 72];

/**
 * These zones have been taken by the spirits and are lost.
 */
var LOST_ZONES:Array<Int> = [];

var PRIMARY_OBJ_ID = "primaryobjid";
var WARCHIEF_ALIVE_OBJ_ID = "warchiefaliveID";
var warchiefUnit:Unit;
var NONE_FORMAT = "NONE";

var DIALOG_SUPPRESS_ID = "dialogsuppressid";
var DIALOG_SUPPRESSED:Bool = false; // The player can choose to skip the dialog in the opening. This makes replays less annoying
var DIALOG_SUPPRESSED_TIMEOUT:Int = 60;

var TIME_TO_OPENING_DIALOG:Int = 7;

var ENDING_NEUTRAL = "neutral";
var ENDING_GOOD = "good";
var ENDING_BAD = "bad";

var SACRIFICE_UNITS_OBJ_ID = "SacrificeUnits";

var currentEnding = ENDING_BAD; // This is the current ending the player will get after studying the stones on the mystery island
var endingObjectiveShown:Bool = false;

var NORTH_ID = "nId";
var EAST_ID = "eId";
var SOUTH_ID = "sId";
var WEST_ID = "wId";

var FIND_STARTING_STONE_ID = "findstartingstone";
var FIND_GRAVEYARD_ID = "findgraveyard";
var FIND_STONE_CIRCLES_ID = "findstonecircles";
var FIND_PORT_SITE_ID = "findportsite";
var BUILD_PORT_SEND_SHIP_ID = "buildportsendship";

var SHIP_DATA = {
	objId: "shipunits",
	objName: "Ship units: 150 Wood, 75 Krowns",
	resources:[{res:Resource.Wood, amt:150}, {res:Resource.Money, amt:75}],
	callback:"shipUnitsCallback",
	shipUnitsCallbackPressed:false,
	firstSend: true,
};

var SPIRIT_DATA = {
	spiritMin:2, // Minimum number of spirits to send in a single attack
	spiritMax:4, // Maximum number of spirits to send in a single attack
	spiritMinGrowth:0.4, // How quickly the minimal attack size grows each year
	spiritMaxGrowth:.6, // How quickly the maximum attack size grows each year

	/**
	 * Maximum number of attacks that can occur at once.
	 *
	 * For example: In year one if the first attack wave is still around when a second wave would be sent, the second wave would instead be cancelled.
	 */
	maxSimultaneousAttacks:1.5,
	maxSimultaneousAttacksGrowth:0.5, // growth each year. Note: when deciding to send an attack, the decimal is dropped. Thus, in Y3 at 2.5, only 2 attacks can happen

	timeofLastAttackSent: 660.0, // when was the last attack, used to decide when to send the next one. Starting value is one month before Y2.

	/**
	 * We don't want to send too many attacks back-to-back, so a heavy penalty is applied to the chance of
	 * another attack happening soon if the previous attack was also soon.
	 * Likewise, if the previous attack had a long delta, a slight bonus is applied to maybe have a back-to-back attack.
	 *
	 * -1 is treated as a special value that applies no modifier.
	 */
	deltaOnPreviousAttack:-1,
	deltaOnPreviousAttackThresholdSeconds:50, // 50 seconds will be the mid-point of the S-curve for how much the penalty will apply. Further from it magnifies result.

	warningBetweenAttacksSeconds:180.0, // How much warning to give to the player of when the next attack will happen
	warningBetweenAttacksSecondsGrowth:-25.0, // How much warning time is lost each year
	warningBetweenAttacksMinimum:80.0, // Players are guaranteed 80 seconds of warning, meaning past Y4 the warnings are all the same.

	timeToCaptureSeconds:80, // How long a spirit must sit on a tile undisturbed before it takes the tile. Reset if a unit enters to challenge the spirit

	timeToFirstAttackSeconds:60 * 12, // 60 seconds per month, so not until Y2 starts.

	timeToSecondWaveInvasionZones:60 * 12 * 3, // After 3 years we add in the second invasion waves candidate zones.

	spawnFactor:5000.0, // Used to reduce the spawn rate

	// The current ongoing attacks
	attackData:[

		// We need something here so Haxe knows what the type is.
		{zone:getZone(START_ZONE_ID), captureProgress:0.0, spiritCount:0, attackTime:0.0, preparedTime:0.0, objIndex:-1, attackedYet:true, dir:NORTH_ID},
	],

	preparedAttackObjs:[
	],

	captureZoneObjs:[
	],

	objectivesUsed:[],


	/**
	 * Triggers dialog once the first tile is taken.
	 */
	firstTileTaken:true,

	/**
	 * If the ghosts take this many tiles, the end-game objective will show warning the player to prevent further losses.
	 */
	tooManyTilesTakenThreshold:8,

	/**
	 * The number of tiles the ghosts can take before the player loses the game, after the threshold was reached.
	 */
	tilesLostRemaining:3,
	tilesLostRemainingObjId:"tilesLostId",

	zonesDirections: [
		{dir:NORTH_ID, zones:[57, 63, 50, 46, 39, 37, 42, 51]},
		{dir:EAST_ID, zones:[25, 30, 38, 41, 48, 45]},
		{dir:SOUTH_ID, zones:[70, 72, 80, 85]},
		{dir:WEST_ID, zones:[84, 76, 82, 90, 87]},
	],
};

var KOBOLD_DATA = {
	befriended: false,
	enemy: false,
	initialContact: false,
	attackKoboldObjId: "Remove the Kobolds",
};

var GIANT_DATA = {
	befriended: false,
	enemy: false,
	initialContact: false,
	attackKoboldObjId: "Remove the Giants",

	destroyReward:[{res:Resource.Wood, amt:200}, {res:Resource.Food, amt:200}],
	destroyTechReward:[Tech.BFTower, Tech.Warcraft], // upgraded towers and warcraft (mil XP => lore&fame)

	befriendReward:3, // free feasts
};

/**
 * All the dialog used in the cutscenes
 *
 * A good chunk of the first few missions/actions in the game is here. However, much is missing.
 * The dialog itself is also a rush job to get a feel for how it would it would sound and feel in game,
 * and needs substantial editing and rewriting.
 *
 * MISSING:
 * Dialog when a ghost first takes a tile
 * Dialog for kobold quest
 * 		Good ending
 *  	Neutral/bad ending
 * Dialog for giant quest
 *  	Good ending
 *  	Bad ending
 * Dialog for sacrifices
 * 		Perhaps dialog after first sacrifices
 * dialog for escaping/winning
 *
 * entirety of neutral
 * entirety of good
 */
var DIALOG = {
	opening:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"We have setup camp here on the center of the island. I can't wait to discover what is so mysterious here."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"We have very little to go on. All we know is most ships can't even land before the fog gets too dense."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Yes, that fog and wind nearly blew us off course. Barely managed to keep the ship going straight."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Let's start expanding, we need to find a lore stone to get started."},
	],

	initial_explore:[
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Do you feel the sensation that we just don't...belong? I have felt unwanted on many Lore hunts before, but not like this"},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"I feel something more. The spirits here have a high energy, yet are calm. Or maybe highly focused. I can't explain it."},
	],

	spirit_appears:[
		{option:{who:Banner.BossFinalHidden, name:"Restless Spirits"}, text:"YoU daRE to DIstuRb ANDER DRAGE Island? YoU were wArDED awaY, yeT HErE yoU ArE."},
		{option:{who:Banner.BossFinalHidden, name:"Restless Spirits"}, text:"Go bAck. NevER retUrn...."},
		{option:{who:Banner.BossFinalHidden, name:"Restless Spirits"}, text:"it aWakENs......"},
		{option:{who:Banner.BossFinalHidden, name:"Restless Spirits"}, text:"BEGONE!"},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"The spirits, their energy is changing. It is bubbling and churning. I fear the island's spiritual world is trying to merge with ours!"},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Then we need to quickly figure out this mystery. I don't think that will be the last of the spirits we see."},
	],

	starter_stone:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"This Lore Stone is unlike others I have seen. We should keep one Loremaster on this stone."},
	],

	found_lore_stone:[
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"That lore stone is a good first start. With it we might be able to discover where to look first."},
	],

	starter_stone_studied:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"We got some information from the stone. Of what we can recover, there was some kind of shipping, or port?, to the North."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"The South is more interesting, maybe. It indicates some kind of mass burial"},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"We should investigate the South first, there might be more there to learn."},
	],

	found_grave_yard:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"This must be the burial site. I can't tell which clan this belonged to, however."},
	],

	graveyard_study_start:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"This graveyard has remains from all the clans. If only we could spend more time digging."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"No time, it looks like the spirits have noticed out presence here, and they don't like it. Assign two Loremasters quickly."},
	],

	graveyard_study_finish:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Finally, we got some really interesting information. It looks like the inhabitants here created the fog."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"They used it to keep others away. For what I can't tell. We might be able to use some of this to get off the island."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Unfortunately, the runes are too unfamiliar and applying them to our ships isn't easy. The first tests failed."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"The kobolds to the East might be able to help, if they are willing."},
	],

	stone_circle_start:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"These stone circles must contain the secrets of the runes and ships. We will need at least 3 loremasters to study them, as they are quite complex."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"The spirits are really angry. The kobolds should have warned us about this!"},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"You will have to guard me and the loremasters while we study. This will take a long time."},
	],

	stone_circle_finish:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"We will need large ships to fit all the runes necessary to make this work, but we can finally get off the island."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Not soon enough if you ask me. These spirit attacks are getting really strong."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Some bad news. We will need to leave from the northern most part of the island. The runes are most powerful in that direction."},
	],

	arrive_at_island:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Amazing! There were ancient dragonkin on this island. But why? And how did they have access to such powerful runes?"},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"We will need to immediately study these stones. Hopefully we have enough villagers to spare to research quickly."},
	],

	// placeholder as the struct needs something
	island_finish_placeholder:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Finished Island"},
	],

	island_finish_good:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Good ending text"},
	],

	island_finish_neutral:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"neutral ending text"},
	],

	island_finish_bad:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Bad ending research finish text, escape start"},
	],

	bad_ending_success:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Bad ending successful, escape message"},
	],

	bad_ending_failure:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Bad ending failure, chastise the player :P"},
	],

	ghosts_take_first_tile:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"When the spirits take an area the fog is so dense that we can't get back in. We will have to defend the most important areas"},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"If they take so many areas that we can't get to the port, I fear we will be trapped here as the island is swallowed whole."},
	],

	ghosts_take_many_tiles:[
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"The ghosts are relentless in taking areas. If any more of the island is lost, so too will our expedition."},
	],

	ghosts_take_too_many_tiles:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"The ghosts have captured too many tiles, and their piercing screams sound all around. We have lost."},
	],

	warchief_has_died:[
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"SVARN! He has been lost...this expedition is lost..."},
	],

	/**
	 * For the good ending, when dying in battle.
	 */
	warchief_sacrificed:[

	],

	/**
	 * If the warchief dies when the angry spirits spawn, but does not die in battle to them.
	 */
	warchief_died_good_ending:[

	],
};

var BAD_ENDING_DATA = {
	villagersSacrificed:0,
	sacrificesRequred:12,
	objectiveId: "AppeaseTheIsland",
	objectiveName: "Appease the Island to Escape",
	progressId:"VillagerSacrifice",
	progressName:"Sacrifice ::value:: units",
	sacrificeButtonPressed: false,
	currentlySacrificing: false,

	escapeObjId:"EscapeTheIslandWithWarChief",
	escapeObjName: "Escape the Island with your Warchief at the North. Gather 200 Wood, 150 Food, 100 Krowns, and 5 Stone.",
	escapeObjResourceRequirements: [{res:Resource.Wood, amt:200}, {res:Resource.Food, amt:150}, {res:Resource.Money, amt:100}, {res:Resource.Stone, amt:5}],
	currentlyEscaping:false,

	revealDialog: DIALOG.island_finish_bad,
	successDialog: DIALOG.bad_ending_success,
	failedDialog: DIALOG.bad_ending_failure,

	finished:false, // This will be set to true if the player wins or loses, so as to trigger a delay after the dialog before end game screen
	successfullyFinished: false, // Will only be set True if the player escapes the island with their WC
	timeFinished:100000.0, // When the player finished. Once set, the game will end sometime after this time value.

};

var neutralEnding = {
	resources: [{res:Resource.Wood, amt:900, objId:"Wood Needed"}, {res:Resource.Food, amt:500, objId:"Food Needed"},
			{res:Resource.Iron, amt:15, objId:"Iron Needed"}, {res:Resource.Money, amt:400, objId:"Krowns Needed"}],
};

var goodEnding = {
	// TODO: requires the most work.
};

var starterStone = {
	 // Indicates if a unit has been assigned for the first time
	firstAssign:true,

	 // How long units have been assigned to the buildings
	studiedTime:0.0,

	// Totoal time, in seconds, required to complete the objective
	studyTimeRequired:120,

	// If the objective is completed
	studied:false,

	// How many lore masters must be assigned, minimum, to earn progress
	studiersRequired:1,

	// Zones where the studying must happen
	zoneIds:[STARTER_CARVED_STONE_TILE_ID],

	// Dialog shown as soon as the studying starts
	startDialog:DIALOG.starter_stone,

	// Dialog shown once finished
	finishDialog:DIALOG.starter_stone_studied,

	// No setup required
	setupFinished:true,

	//
	findNextObjectiveId:FIND_GRAVEYARD_ID,
}

var graveYardStudying = {
	firstAssign:true,
	studiedTime:0.0,
	studyTimeRequired:240,
	studied:false,
	studiersRequired:2,
	zoneIds:[GRAVEYARD_ZONE_ID],
	startDialog:DIALOG.graveyard_study_start,
	finishDialog:DIALOG.graveyard_study_finish,
	setupFinished:true, // No setup required
	findNextObjectiveId:FIND_STONE_CIRCLES_ID,
}

var stoneCircleStudying = {
	firstAssign:true,
	studiedTime:0.0,
	studyTimeRequired:360,
	studied:false,
	studiersRequired:3,
	zoneIds:LORE_CIRCLE_ZONE_IDS,
	startDialog:DIALOG.stone_circle_start,
	finishDialog:DIALOG.stone_circle_finish,
	setupFinished:true, // No setup required
	findNextObjectiveId:FIND_PORT_SITE_ID,
}

var islandStudying = {
	firstAssign:true,
	studiedTime:0.0,
	studyTimeRequired:90,
	studied:false,
	studiersRequired:1,
	zoneIds:[MYSTERY_ZONE_ID],
	startDialog:DIALOG.arrive_at_island,
	finishDialog:DIALOG.island_finish_placeholder,
	setupFinished:false, // Only objective that requires setup (revealing/taking the island)
	findNextObjectiveId:null,
}

/**
 * Required function, called automatically by the game engine.
 */
function init() {
	if (state.time == 0)
		onFirstLaunch();
}

function onFirstLaunch() {

	state.removeVictory(VictoryKind.VMoney);
    state.removeVictory(VictoryKind.VFame);
    state.removeVictory(VictoryKind.VLore);

	debug("Map Version: " + VERSION);

	// Disabled events. We shall send our own >:)
	noEvent();

	msg("Setting up human player data");
	human = me();
	var hall = human.getTownHall();
	warchiefUnit = summonWarchief(human, getZone(START_ZONE_ID), hall.x + 7, hall.y + 7);
	human.addResource(Resource.Food, 150);
	human.addResource(Resource.Wood, 150);
	human.addResource(Resource.Money, 75);

	msg("setting up obj");
	setupObjectives();

	msg("Checking debug data setup");

	// Clean up type data placeholders
	SPIRIT_DATA.attackData.pop();

	// ---- TESTING FOR BAD ENDING
	if(DEBUG.BAD) {
		human.addResource(Resource.Wood, 1000);
		human.addResource(Resource.Money, 1000);
		var z = getZone(PORT_ZONE_ID);
		human.discoverZone(z); // TODO FOR TESTING
		// human.discoverZone(getZone(MYSTERY_ZONE_ID));
		human.discoverZone(getZone(57));
		human.discoverZone(getZone(50));
		killAllUnits([z, getZone(57), getZone(50)]);
		human.takeControl(z);
		getZone(PORT_ZONE_ID).addUnit(Unit.Villager, 14, human);
		BAD_ENDING_DATA.currentlySacrificing = true;
		human.addResource(Resource.Food, 500);
		human.addResource(Resource.Stone, 5);
	}

	// ---- END TESTING FOR BAD ENDING

	if(DEBUG.ALL_EXPLORED){
		human.discoverAll();
	}

	// Really amps up the attacks for testing
	if(DEBUG.SPIRITS_FAST) {
		SPIRIT_DATA.timeToFirstAttackSeconds = 20;
		human.discoverAll();
		SPIRIT_DATA.timeofLastAttackSent = 10.0;
		SPIRIT_DATA.warningBetweenAttacksSeconds = 10;
		SPIRIT_DATA.warningBetweenAttacksMinimum = 10;
		SPIRIT_DATA.maxSimultaneousAttacks = 4;
		SPIRIT_DATA.spawnFactor = 1000;
	}
}

/**
 * Required function, called automatically by the game engine.
 */
function regularUpdate(dt : Float) {

	// Used to print messages occasionally
	DEBUG.TIME_INDEX++;

	checkObjectives();

	checkDialog();

	checkStudying();

	checkSpirits();

	checkKobolds();

	checkGiants();

	checkEndGame();

	if(toInt(DEBUG.TIME_INDEX) % 30 == 0)
		msg("running...");
}

/**
 * This triggers the Game end victory/defeat for the player; showing the shining or broken shield, and allowing the player to quit.
 * In all cases, a slight delay is applied to when the player won after the dialog finishes before transitioning.
 */
function checkEndGame() {
	switch(currentEnding) {
		case ENDING_BAD:
			if(BAD_ENDING_DATA.finished && BAD_ENDING_DATA.timeFinished + 4 < state.time) {
				if(BAD_ENDING_DATA.successfullyFinished) {
					human.customVictory("You have escaped Drage Ander!", "placeholder");
				}
				else{
					customDefeat("You have failed to escape Drage Ander Island, and your soul is trapped forever beneath the island!");
				}
			}
	}
}

function checkKobolds() {

}

function checkGiants() {

}

/**
 * Manages updating the progress and visibility of all the objectives.
 */
function checkObjectives() {

	if(state.objectives.getStatus(FIND_STARTING_STONE_ID) != OStatus.Done && human.hasDiscovered(getZone(STARTER_CARVED_STONE_TILE_ID))){
		msg("Found lore stone");
		state.objectives.setStatus(FIND_STARTING_STONE_ID, OStatus.Done);
		sendCameraToBuilding(findBuildingInZone(STARTER_CARVED_STONE_TILE_ID, Building.CarvedStone));
		pauseAndShowDialog(DIALOG.found_lore_stone);
	}

	if(state.objectives.getStatus(FIND_GRAVEYARD_ID) != OStatus.Done && human.hasDiscovered(getZone(GRAVEYARD_ZONE_ID))){
		msg("Found graveyard stone");
		state.objectives.setStatus(FIND_GRAVEYARD_ID, OStatus.Done);
		sendCameraToZone(GRAVEYARD_ZONE_ID);
		pauseAndShowDialog(DIALOG.found_grave_yard);
	}

	if(state.objectives.isVisible(DIALOG_SUPPRESS_ID) && state.time > DIALOG_SUPPRESSED_TIMEOUT) {
		state.objectives.setVisible(DIALOG_SUPPRESS_ID, false);
	}

	if(stoneCircleStudying.studied && !islandStudying.setupFinished) {
		msg("Setting up ship data for mystery island.");
		islandStudying.setupFinished = true;
		state.objectives.setVisible(SHIP_DATA.objId, true);
	}

	checkWarchiefAlive();

	// Defeat if the player loses too many tiles
	if(state.objectives.isVisible(SPIRIT_DATA.tilesLostRemainingObjId)) {
		rarelyPrint("Player triggered possible end game to spirits.");
		state.objectives.setCurrentVal(SPIRIT_DATA.tilesLostRemainingObjId, LOST_ZONES.length - SPIRIT_DATA.tooManyTilesTakenThreshold);
		if(LOST_ZONES.length >= SPIRIT_DATA.tooManyTilesTakenThreshold + SPIRIT_DATA.tilesLostRemaining) {
			msg("Game lost to spirits claiming tiles");
			state.objectives.setStatus(SPIRIT_DATA.tilesLostRemainingObjId, OStatus.Missed);
			pauseAndShowDialog(DIALOG.ghosts_take_too_many_tiles);
			customDefeat("The spirits have claimed the island.");
		}
	}

	if(SHIP_DATA.shipUnitsCallbackPressed) {

		// Only reveal the island after sending the first boat of units
		if(SHIP_DATA.firstSend){
			SHIP_DATA.firstSend = false;
			human.takeControl(getZone(MYSTERY_ZONE_ID));
			human.discoverZone(getZone(MYSTERY_ZONE_ID));

			// TODO: trigger some dialog on being discovered?
		}

		SHIP_DATA.shipUnitsCallbackPressed = false;
		if(meetsRequirements(SHIP_DATA.resources) && getZone(PORT_ZONE_ID).units.length > 0) {
			takeResources(SHIP_DATA.resources);

			// only move so many units at a time, picking randomly
			var units = [].concat(getZone(PORT_ZONE_ID).units.slice(0, 4));
			var types = [];
			for(u in units) {
				types.push(u.kind);
				u.die(true, false);
			}

			drakkar(human, getZone(MYSTERY_ZONE_ID), getZone(PORT_LAUNCH_ZONE_ID), 0, 0, types, .1);
		}
	}

	// The three endings all have their own multi-objective quest line that is tracked separately.
	switch(currentEnding) {
		case ENDING_BAD: manageBadEndingObjectives();
	}
}

function findBuildingInZone(id:Int, type:BuildingKind) {
	var z = getZone(id);
	for(b in z.buildings) {
		if(b.kind == type) {
			return b;
		}
	}

	return null;
}

function sendCameraToZone(id:Int) {
	var zone = getZone(id);
	moveCamera({x:zone.x, y:zone.y});
}

function sendCameraToBuilding(building:Building) {
	moveCamera({x:building.x, y:building.y});
	setZoom(1);
}

/**
 * The warchief must be kept alive, or the mission is lost.
 *
 * The only exception is if we are in the GOOD ending.
 */
function checkWarchiefAlive() {
	if(warchiefUnit.life <= 0) {
		if(currentEnding == ENDING_GOOD) {
			handleWarchiefDeathGoodEnding();
		}
		else{
			state.objectives.setStatus(WARCHIEF_ALIVE_OBJ_ID, OStatus.Missed);
			pauseAndShowDialog(DIALOG.warchief_has_died);
			customDefeat("Svarn has fallen in battle and the spirits have taken your clan.");
		}
	}
}

/**
 * For the good ending, the warchief must die in battle to one of the Angry Spirit incarnations to complete
 * his self-sacrifice. Dying elsewhere will lose the mission.
 *
 * NOTE: battle here is described as "being in the same tile as one of the angry spirits", as I can't tell who
 * killed a given unit anyway.
 */
function handleWarchiefDeathGoodEnding() {

}

/**
 * The bad ending is a two-part quest, caused because the player was a terrible
 * person to the neutrals on the island.
 *
 * 				---- PART ONE ----
 * The first part requires sacrificing units to the altar after shipping over the units
 * in cheap boats. Any units sitting on the port tile will get shipped. If more than four,
 * then units are randomly picked. Once the sufficient sacrificecs are made, this part completes.
 * The second part of the quest will then immediately trigger.
 *
 * TODO: maybe purposefully exclude the WC so as to not frustate the player?
 * TODO: maybe prioritize villagers before anything else?
 *
 * 				---- PART TWO ----
 * This part is passive. As long as the player has the resources needed to build the ship and their
 * warchief on the port tile, they will automatically escape, triggering an expositional dialog, and then victory.
 */
function manageBadEndingObjectives() {

	// PART ONE
	if(BAD_ENDING_DATA.currentlySacrificing) {
		// We do a lot of "heavy lifting" in scanning for units, so this has to be in regularUpdate
		if(BAD_ENDING_DATA.sacrificeButtonPressed) {
			BAD_ENDING_DATA.sacrificeButtonPressed = false;
			var units = getZone(MYSTERY_ZONE_ID).zone.units;

			// we need to make a copy. The original array will have units deleted from it as we kill them
			// which will mean the array will shrink as we iterate over it, resulting in
			// only CEIL(n/2) dying instead.
			var killEm = [].concat(units);
			BAD_ENDING_DATA.villagersSacrificed += units.length;

			for(u in killEm){
				u.die(false, true);
			}
			msg("Finished killing");
		}

		if(BAD_ENDING_DATA.villagersSacrificed >= BAD_ENDING_DATA.sacrificesRequred) {

			// Cleanup the sacrifice stuff
			state.objectives.setStatus(BAD_ENDING_DATA.progressId, OStatus.Done);
			state.objectives.setVisible(SHIP_DATA.objId, false);
			state.objectives.setVisible(SACRIFICE_UNITS_OBJ_ID, false);
			state.objectives.setStatus(BAD_ENDING_DATA.objectiveId, OStatus.Done);

			// TODO show dialog to escape

			// Show the final step in the quest, escape with your warchief
			BAD_ENDING_DATA.currentlyEscaping = true;
			BAD_ENDING_DATA.currentlySacrificing = false;
			state.objectives.setVisible(BAD_ENDING_DATA.escapeObjId, true);
		}

		state.objectives.setCurrentVal(BAD_ENDING_DATA.progressId, BAD_ENDING_DATA.villagersSacrificed);
	}

	// PART TWO
	else if(BAD_ENDING_DATA.currentlyEscaping) {

		// This helps provide a slight delay, so the player sees they completed the objective before it fades
		if(state.objectives.isVisible(BAD_ENDING_DATA.progressId))
			state.objectives.setVisible(BAD_ENDING_DATA.progressId, false);

		if(meetsRequirements(BAD_ENDING_DATA.escapeObjResourceRequirements)) {
			var units = getZone(PORT_ZONE_ID).units;
			var wcOnTile = false;
			for(u in units) {
				if(u == human.getWarchief()) {
					u.die(true, false);
					wcOnTile = true;
				}
			}

			if(wcOnTile) {

				// This isn't really necessary, as the player will shortly win anyway, but it may make it seem
				// like the player just barely escaped, which is a good feeling
				takeResources(BAD_ENDING_DATA.escapeObjResourceRequirements);

				state.objectives.setStatus(PRIMARY_OBJ_ID, OStatus.Done);
				state.objectives.setStatus(BAD_ENDING_DATA.escapeObjId, OStatus.Done);

				// TODO: show a ship leaving, maybe?

				pauseAndShowDialog(BAD_ENDING_DATA.successDialog);
				BAD_ENDING_DATA.finished = true;
				BAD_ENDING_DATA.timeFinished = state.time;
				BAD_ENDING_DATA.successfullyFinished = true; // Hooray! You are a terrible person that killed their followers to get your own skin to safety! Yay! :D
			}
		}
	}
}

/**
 * Manages sending dialog to the player at certain times or under certain conditions the player triggers.
 *
 * We clear the dialog array after use as a simple method of not showing the same dialog twice.
 */
function checkDialog() {
	if(DIALOG.opening.length > 0 && TIME_TO_OPENING_DIALOG < state.time) {
		msg("Opening dialog shown");
		pauseAndShowDialog(DIALOG.opening);
		DIALOG.opening = [];
		state.objectives.setVisible(FIND_STARTING_STONE_ID, true);
	}

	if(DIALOG.initial_explore.length > 0 && human.discovered.length == 3) {
		msg("Initial explore dialog shown");
		pauseAndShowDialog(DIALOG.initial_explore);
		state.objectives.setVisible(PRIMARY_OBJ_ID, true);
		DIALOG.initial_explore = [];
	}

	if(DIALOG.spirit_appears.length > 0 && human.discovered.length == 5) {
		msg("Spirit Appears dialog shown");
		pauseAndShowDialog(DIALOG.spirit_appears);
		DIALOG.spirit_appears = [];
	}

	if(SPIRIT_DATA.firstTileTaken && LOST_ZONES.length >= 1) {
		msg("Spirits took first tile dialog shown");
		var zone = getZone(LOST_ZONES[0]);
		moveCamera({x:zone.x, y:zone.y});
		pauseAndShowDialog(DIALOG.ghosts_take_first_tile);
		DIALOG.ghosts_take_first_tile = [];
		SPIRIT_DATA.firstTileTaken = false;
	}

	if(!state.objectives.isVisible(SPIRIT_DATA.tilesLostRemainingObjId) && LOST_ZONES.length >= SPIRIT_DATA.tooManyTilesTakenThreshold) {
		msg("Spirit defeat countdown triggered");
		pauseAndShowDialog(DIALOG.ghosts_take_many_tiles);
		DIALOG.ghosts_take_many_tiles = [];
		state.objectives.setVisible(SPIRIT_DATA.tilesLostRemainingObjId, true);
	}
}

/**
 * The player must study multiple lore sites for varying amounts of time. All the sites
 * function virtually the same, however once started the game will change. This helps to
 * manage the player discovering and starting studying of these sites.
 */
function checkStudying() {

	// This neatly ensures the player does each lore site in order: Starting stone next to townhall,
	// graveyard near the shore, and then the lore stone circles.
	if(!starterStone.studied)
		checkStudyingProgress(starterStone);
	else if(!graveYardStudying.studied)
		checkStudyingProgress(graveYardStudying);
	else if(!stoneCircleStudying.studied)
		checkStudyingProgress(stoneCircleStudying);
	else if(!islandStudying.studied)
		checkStudyingProgress(islandStudying);
	else if(!endingObjectiveShown) {
		endingObjectiveShown = true;
		switch(currentEnding) {
			case ENDING_BAD: setupBadEnding();
			case ENDING_NEUTRAL: setupNeutralEnding();
			case ENDING_GOOD: setupGoodEnding();
		}
	}
}

function setupBadEnding() {
	state.objectives.setVisible(BAD_ENDING_DATA.objectiveId, true);
	state.objectives.setVisible(BAD_ENDING_DATA.progressId, true);
	state.objectives.setVisible(SACRIFICE_UNITS_OBJ_ID, true);

	pauseAndShowDialog(BAD_ENDING_DATA.revealDialog);
}

function setupNeutralEnding() {

}

function setupGoodEnding() {

}

/**
 * This does the work of managing the progress of each lore site. Dialog is triggered upon
 * first study and upon completion.
 */
function checkStudyingProgress(tracker) {

	if(DEBUG.SKIP_STUDYING) {
		if(tracker == starterStone && state.time > 30) {
			tracker.studied = true;
		}
		else if(tracker == graveYardStudying && state.time > 40) {
			tracker.studied = true;
		}
		else if(tracker == stoneCircleStudying && state.time > 50) {
			tracker.studied = true;
		} else if(tracker == islandStudying && state.time > 60) {
			tracker.studied = true;
		}
	}

	// Just a simple guard to make sure we don't do this by accident
	if(tracker.studied) {
		msg("Study complete, why checking progress? Shouldn't happen");
		return;
	}

	var units = countUnitTypesOnTile(tracker.zoneIds, Unit.RuneMaster);

	if(units > 0) {
		if(tracker.firstAssign) {
			tracker.firstAssign = false;
			pauseAndShowDialog(tracker.startDialog);
		}

		// progress is only earned if at least the required is met. If more than met,
		// a slight bonus is applied
		tracker.studiedTime +=
			tracker.studiersRequired < units ? 0 :
			tracker.studiersRequired == units ? 0.5 : 0.5 = (0.15 * units - tracker.studiersRequired);

		sometimesPrint("Progress: " + tracker.studiedTime);
	}

	// Once we finish studying we can show the dialog and finish this part of the quest
	if(!tracker.studied && tracker.studiedTime >= tracker.studyTimeRequired) {
		tracker.studied = true;
		pauseAndShowDialog(tracker.finishDialog);
		var next = tracker.findNextObjectiveId;

		// The last objective has nothing next to find and will be null
		if(next != null) {
			state.objectives.setVisible(next, true);
		}
	}
}

/**
 * Spirits will act against the player, with typically more and more pressure the further
 * the player is in the quest. Pressure will also be applied if the player takes too long,
 * so as to prevent turtling before the objective gets triggered.
 */
function checkSpirits() {

	if(INVASION_SECOND_STARTING_WAVE_ZONES.length != 0 && SPIRIT_DATA.timeToSecondWaveInvasionZones < state.time) {

		// We don't want to accidentally add in zones that have already been taken
		// or are new candidates for invading already.
		for(z in LOST_ZONES.concat(INVASION_ZONES)) {
			INVASION_SECOND_STARTING_WAVE_ZONES.remove(z);
		}
		INVASION_ZONES = INVASION_ZONES.concat(INVASION_SECOND_STARTING_WAVE_ZONES);
	}

	prepareNewAttacks();

	launchPreparedAttacks();

	manageCurrentAttacks();
}

/**
 * Attacks that have been scheduled have their progress updated, and if they are ready to attack, they are
 * sent at the zone. After preparation is complete, attacks are then handled in manageCurrentAttacks().
 */
function launchPreparedAttacks() {
	for(attack in SPIRIT_DATA.attackData) {
		if(!attack.attackedYet && attack.attackTime < state.time) {
			addFoes([{z:attack.zone.id, u:Unit.SpecterWarrior, nb:attack.spiritCount}]);
			attack.attackedYet = true;
			msg("Launching attack in zone: " + attack.zone.id);

			var attackObj = getAttackObjective(attack.objIndex);
			state.objectives.setVisible(attackObj.id, true);
			var prep = getPreparedObjective(attack.objIndex);
			state.objectives.setVisible(prep.id, false);
		}
		else{
			var prep = getPreparedObjective(attack.objIndex);

			// The weird math below: normalizes the time to launch to be a percent between 0 and 100, which is much nicer and less confusing than a count-up to the exact time in seconds
			state.objectives.setCurrentVal(prep.id, toInt(((attack.attackTime - attack.preparedTime) - (attack.attackTime - state.time) / (attack.attackTime - attack.preparedTime) * 100)));
		}
	}
}

/**
 * Checks the capture progress of the spirits, if a wave was defeated, and stealing tiles.
 */
function manageCurrentAttacks() {
	var removeAttacks = [];
	var uncontestedAttacks = [];
	for(attack in SPIRIT_DATA.attackData) {
		if(!attack.attackedYet)
			continue;
		var units = attack.zone.units;
		var ghosts = 0;
		var playerUnits = 0;
		for(u in units) {
			if(u.kind == Unit.SpecterWarrior)
				ghosts++;
			else if(u.owner == human)
				playerUnits++;
		}

		// If all ghosts are dead, this attack ends and will be cleaned up
		if(ghosts == 0){
			removeAttacks.push(attack);
		}

		// If no player units are present, then the ghosts earn progress towards capturing
		else if(playerUnits == 0) {
			attack.captureProgress += 0.5;
			var attackObj = getAttackObjective(attack.objIndex);
			state.objectives.setCurrentVal(attackObj.id, toInt(attack.captureProgress / SPIRIT_DATA.timeToCaptureSeconds * 100));

			if(attack.captureProgress >= SPIRIT_DATA.timeToCaptureSeconds) {
				ghostsTakeZone(attack.zone);
				removeAttacks.push(attack);
			}
		}

		// otherwise we lose progress; the ghosts are being attacked! :O
		else{
			attack.captureProgress -= 1;
			attack.captureProgress = attack.captureProgress < 0 ? 0 : attack.captureProgress;
			var attackObj = getAttackObjective(attack.objIndex);
			state.objectives.setCurrentVal(attackObj.id, toInt(attack.captureProgress / SPIRIT_DATA.timeToCaptureSeconds * 100));
		}
	}

	// we couldn't do this in the previous loop as we would be modifying an array while iterating over it.
	for(f in removeAttacks) {
		SPIRIT_DATA.attackData.remove(f);
		var attack = getAttackObjective(f.objIndex);
		state.objectives.setVisible(attack.id, false);
		SPIRIT_DATA.objectivesUsed.remove(f.objIndex);
	}

	// Now that we have updated the list of remaining attacks, we can check which cardinal directions are being attack/prepared
	var dirs = [];
	var notUsed = [NORTH_ID, EAST_ID, SOUTH_ID, WEST_ID];
	for(a in SPIRIT_DATA.attackData) {
		var d = notUsed.indexOf(a.dir);
		if(d != -1) {
			notUsed.remove(a.dir);
			dirs.push(a.dir);
		}
	}

	/**
	 * The reason we break up the below into two calls is because we can't just setVisible multiple times
	 * under a single call of regularUpdate. It only takes the first use, so we need to make sure we correctly set visibility
	 * exactly once.
	 */
	for(d in dirs) {
		state.objectives.setVisible(d, true);
	}

	for(d in notUsed) {
		state.objectives.setVisible(d, false);
	}
}

/**
 * If a ghost sits in a zone too long uncontested, then the ghost takes it.
 * This will cover the zone, prevent the player from scounting it, and add all its
 * neighbors (except the safe zones) as candidates to be invaded next.
 */
function ghostsTakeZone(zone:Zone) {
	human.coverZone(zone);
	zone.allowScouting = false;
	INVASION_ZONES.remove(zone.id);
	LOST_ZONES.push(zone.id);

	// Add all neighbor zones as targets for invasion.
	for(z in zone.next) {
		if(INVASION_ZONES.indexOf(z.id) == -1 && LOST_ZONES.indexOf(z.id) == -1 && SAFE_ZONES.indexOf(z.id) == -1)
			INVASION_ZONES.push(z.id);
	}
}

/**
 * Decides when a new attack should be launched based on some rolling probability over time.
 * When an attack is decided, it will pick a zone not already being attacked (either currently or queued)
 * and then inserts it into the attack queue.
 */
function prepareNewAttacks() {
	var currentYear = timeToYears(state.time);

	// Attacks will only start under these two conditions.
	// This is to: help players who are new and need the extra time so they get the full year before the first attack wave
	// For experienced players, this helps to slow them down if they rush objectives.
	if(graveYardStudying.studied || state.time > SPIRIT_DATA.timeToFirstAttackSeconds) {
		if(SPIRIT_DATA.attackData.length >= toInt(SPIRIT_DATA.maxSimultaneousAttacks + (SPIRIT_DATA.maxSimultaneousAttacksGrowth * currentYear)))
			return;

		var delta = state.time - SPIRIT_DATA.timeofLastAttackSent;
		delta = delta < 0 ? 0 : delta; // If the player rushes the second objective before Y2, this can be negative.
		var proba = delta / SPIRIT_DATA.spawnFactor; // normalize the distribution over 240 seconds.
		var prevAttackTime = SPIRIT_DATA.deltaOnPreviousAttack;

		// we apply a slight linear shift in the probability of an attack to make back-to-back slightly less likely, and longer than the threshold slightly more likely
		if(SPIRIT_DATA.deltaOnPreviousAttack >= 0) {
			proba = prevAttackTime < SPIRIT_DATA.deltaOnPreviousAttackThresholdSeconds ? proba * 0.1 : proba * 1.1;
		}

		rarelyPrint("PROBABILITY: " + proba + " RANDOM: " + random());

		if(random() < proba){
			var min = toInt(SPIRIT_DATA.spiritMin + (SPIRIT_DATA.spiritMinGrowth * currentYear));
			var max = toInt(SPIRIT_DATA.spiritMax + (SPIRIT_DATA.spiritMaxGrowth * currentYear));
			SPIRIT_DATA.deltaOnPreviousAttack = toInt(delta);

			// We add one as randomInt works 0 inclusively to max exclusively
			var spirits = randomInt((max - min) + 1) + min;

			// We don't want to send an attack where we are currently attacking
			var choices = [].concat(INVASION_ZONES);
			for(a in SPIRIT_DATA.attackData)
				choices.remove(a.zone.id);
			var zoneId = choices[randomInt(choices.length)];

			// determine warning
			var warning = SPIRIT_DATA.warningBetweenAttacksSeconds - (SPIRIT_DATA.warningBetweenAttacksSecondsGrowth * currentYear);
			warning = warning < SPIRIT_DATA.warningBetweenAttacksMinimum ? SPIRIT_DATA.warningBetweenAttacksMinimum : warning;

			populateAttackData(getZone(zoneId), spirits, warning + state.time);
			SPIRIT_DATA.timeofLastAttackSent = state.time;
		}
	}
	else {
		rarelyPrint("Not ready to send attacks");
	}
}

/**
 * Creates the attack struct and inserts it into an attack "queue".
 *
 * It also reserves the use of an unused objective to track capture progress.
 */
function populateAttackData(zone:Zone, spiritCount:Int, attackTime:Float) {

	// find an unused objective
	// TODO: maybe use a second queue to keep track of unused? More overhead but more obvious than this
	var index = 0;
	var i = 0;
	while(i < 10) {
		if(SPIRIT_DATA.objectivesUsed.indexOf(i) == -1){
			SPIRIT_DATA.objectivesUsed.push(i);
			index = i;
			break;
		}
		i++;
	}

	// prepare the objectives that will represent this attack.
	msg("Setting up attack in" + zone.id + ", Count: " + spiritCount + " at " + attackTime + " INDEX: " + index);
	var prepare = getPreparedObjective(index);
	state.objectives.setCurrentVal(prepare.id, 0);
	state.objectives.setVisible(prepare.id, true);
	state.objectives.setStatus(prepare.id, OStatus.Empty);
	var attack = getAttackObjective(index);
	state.objectives.setCurrentVal(attack.id, 0);
	state.objectives.setStatus(attack.id, OStatus.Empty);
	var dir = determineCardinality(zone.id);

	SPIRIT_DATA.attackData.push({zone:zone, captureProgress:0.0, spiritCount:spiritCount, attackTime:attackTime, preparedTime:state.time, objIndex:index, attackedYet:false, dir:dir});
}

function determineCardinality(z:Int): String {
	for(c in SPIRIT_DATA.zonesDirections) {
		if(c.zones.indexOf(z) != -1)
			return c.dir;
	}

	debug("Invalid zone for spawning, no known direction???");
}

function getAttackObjective(index:Int):{id:String, name:String} {
	return SPIRIT_DATA.captureZoneObjs[index];
}

function getPreparedObjective(index:Int):{id:String, name:String} {
	return SPIRIT_DATA.preparedAttackObjs[index];
}

/**
 * Returns a whole number of years that have passed.
 */
function timeToYears(time:Float):Int {
	return toInt(time / 720.0);
}

/**
 * Will count all of one type of unit in a given set of zones.
 */
function countUnitTypesOnTile(zoneIds:Array<Int>, unit:UnitKind):Int {
	var units = 0;
	for(z in zoneIds) {
		for(u in getZone(z).units) {
			if(u.kind == unit)
				units++;
		}
	}

	return units;
}

/**
 * Called if the player clicks the "Disable" button at the beginning of the game. It will
 * prevent all dialog from playing.
 *
 * The point is to prevent fatigue from players trying to master the map.
 *
 * TODO: Should this only cover unnecessary dialog?
 */
function disableDialogCallback() {
	DIALOG_SUPPRESSED = true;
	state.objectives.setVisible(DIALOG_SUPPRESS_ID, false);
}

function shipUnitsCallback() {
	SHIP_DATA.shipUnitsCallbackPressed = true;
}

function sacrificeUnitsCallback() {
	// We can't do a lot of work in a callback (it won't finish), so instead we will mark expensive actions,
	// like searching a zone, for completion during the regularUpdate call.
	BAD_ENDING_DATA.sacrificeButtonPressed = true;
}

/**
 * Given an array of resources structs {Resource, Int}, will return True if the player has all the resources
 */
function meetsRequirements(res:Array<{res:ResourceKind, amt:Int}>): Bool {
	for(r in res) {
		if(human.getResource(r.res) < r.amt)
			return false;
	}

	return true;
}

/**
 * Given an array of resources structs {Resource, Int}, will take the resources from the player
 */
function takeResources(res:Array<{res:ResourceKind, amt:Int}>) {
	for(r in res) {
		human.addResource(r.res, r.amt * -1); // we can use this function to take resources by turning it negative
	}
}

/**
 * Given an array of resources structs {Resource, Int}, will give the resources to the player
 */
function giveResources(res:Array<{res:ResourceKind, amt:Int}>) {
	for(r in res) {
		human.addResource(r.res, r.amt);
	}
}

/**
 * Given a Month and Year, it will return the number of real time seconds that
 * represents. A Month is defined as 60 seconds long. One year is therefore
 * 720 seconds or 12 minutes.
 */
function calToSeconds(month:Int, year:Int) {

	// 60 seconds per month, and 12 months in a year
	return month * 60 + year * 60 * 12;
}

/**
 * A helper function to show multiple lines of text.
 */
function pauseAndShowDialog(dialog) {

	// The checkStudying function may pass in empty dialog, which is fine,
	// we just don't want to pause and unpause unnecessarily.
	if(dialog.length == 0)
		return;

	if(!DIALOG_SUPPRESSED) {
		setPause(true);
		for(d in dialog) {
			talk(d.text, d.option); // editor doesn't understand talk
		}
		setPause(false);
	}
}

/**
 * A wrapper that makes sure debug messages are only printed if turned on. Makes cleaning
 * up for publishing to steam workshop easier.
 */
function msg(m:String) {
	if(DEBUG.MESSAGES)
		debug(m);
}

/**
 * When sending debug messages we sometimes want to see the progress of something, but not every update.
 * This function is a wrapper that makes sure the provided message is only shown every 3 calls to regularUpdate.
 */
function sometimesPrint(m:String) {
	if(toInt(DEBUG.TIME_INDEX) % 3 == 0)
		msg(m);
}

/**
 * When sending debug messages we rarely want to see the progress or status of something, but not every update.
 * This function is a wrapper that makes sure the provided message is only shown every 7 calls to regularUpdate.
 */
function rarelyPrint(m:String) {
	if(toInt(DEBUG.TIME_INDEX) % 7 == 0)
		msg(m);
}

/**
 * Objectives show up on the screen in the order they were added, so the ordering below
 * is somewhat odd, but is meant to help ensure the most primary focus is near the top.
 */
function setupObjectives() {

	if(DEBUG.QUICK_BUTTON) {
		state.objectives.add("QuickComplete", "Complete Next Step", {visible:true}, {name:"Next", action:"quickButtonCallback"});
	}

	state.objectives.add(PRIMARY_OBJ_ID, "Discover the Secret of the Isle", {visible:false});

	state.objectives.add(SPIRIT_DATA.tilesLostRemainingObjId, "Don't lose more territory to the ghosts", {visible:false, showProgressBar:true, goalVal:SPIRIT_DATA.tilesLostRemaining});
	state.objectives.add(WARCHIEF_ALIVE_OBJ_ID, "Svarn must survive", {visible:true});

	// Finding Objectives
	state.objectives.add(FIND_STARTING_STONE_ID, "Find a lore stone", {visible:false});
	state.objectives.add(FIND_GRAVEYARD_ID, "Find the burial site", {visible:false});
	state.objectives.add(FIND_STONE_CIRCLES_ID, "Find the stone circles", {visible:false});
	state.objectives.add(FIND_PORT_SITE_ID, "Find the old northern port", {visible:false});
	state.objectives.add(BUILD_PORT_SEND_SHIP_ID, "Build a port and send a ship", {visible:false});

	// Good, Neutral, Bad primary objectives
	state.objectives.add(BAD_ENDING_DATA.objectiveId, BAD_ENDING_DATA.objectiveName, {visible:false});
	state.objectives.add(BAD_ENDING_DATA.progressId, BAD_ENDING_DATA.progressName, {visible:false, showProgressBar:true, goalVal:BAD_ENDING_DATA.sacrificesRequred});

	// Good, Neutral, Bad secondary objectives
	state.objectives.add(BAD_ENDING_DATA.escapeObjId, BAD_ENDING_DATA.escapeObjName, {visible:false});

	// TODO: should this be here?
	state.objectives.add(DIALOG_SUPPRESS_ID, "Disable dialog", {visible:true}, {name:"Disable", action:"disableDialogCallback"}); // the editor doesn't understand buttons

	// Misc objectivs, or actionable buttons for objectives
	state.objectives.add(SHIP_DATA.objId, SHIP_DATA.objName, {visible:false}, {name:"Ship Units", action:SHIP_DATA.callback});
	state.objectives.add(SACRIFICE_UNITS_OBJ_ID, "Sacrifice Units to the Altar", {visible:false}, {name:"Sacrifice All", action:"sacrificeUnitsCallback"});

	state.objectives.add(NORTH_ID, "Attack In the North", {visible:false});
	state.objectives.add(EAST_ID, "Attack In the East", {visible:false});
	state.objectives.add(SOUTH_ID, "Attack In the South", {visible:false});
	state.objectives.add(WEST_ID, "Attack In the West", {visible:false});

	// There could feasibly be this many attacks at once, though I imagine at this point a player would lose....
	var i = 0;
	while(i < 10) {
		var obj = {id:i+"prepId", name:"Spirits are Preparing..."};
		SPIRIT_DATA.preparedAttackObjs.push(obj);
		state.objectives.add(obj.id, obj.name, {visible:false, showProgressBar:true, goalVal:100});
		obj = {id:i+"capId", name:"Capturing Zone"};
		SPIRIT_DATA.captureZoneObjs.push(obj);
		state.objectives.add(obj.id, obj.name, {visible:false, showProgressBar:true, goalVal:100});
		i++;
	}
}

/**
 * DEBUG FUNCTION
 *
 * Used for quickly "completing" a step of an objective to see if completing
 * and transitioning between objectives works correctly.
 */
function quickButtonCallback() {
	switch(DEBUG.QUICK_BUTTON_INDEX) {
		case 0: human.discoverZone(getZone(STARTER_CARVED_STONE_TILE_ID)); debug("Starter stone revealed");
		case 1: starterStone.studiedTime = starterStone.studyTimeRequired; debug("Studying of starting stone complete");

		case 2: human.discoverZone(getZone(GRAVEYARD_ZONE_ID)); debug("graveyard explored");
		case 3: graveYardStudying.studiedTime = graveYardStudying.studyTimeRequired; debug("graveyard studied");

		case 4: human.discoverZone(getZone(LORE_CIRCLE_ZONE_IDS[0])); debug("explore first circle");
		case 5: human.discoverZone(getZone(LORE_CIRCLE_ZONE_IDS[1])); debug("explore second circle");
		case 6: stoneCircleStudying.studiedTime = stoneCircleStudying.studyTimeRequired; debug("Circles studied");

		case 7: human.discoverZone(getZone(PORT_ZONE_ID)); debug("port explored");
		case 8: graveYardStudying.studiedTime = graveYardStudying.studyTimeRequired; debug("port built");

		case 9: graveYardStudying.studiedTime = graveYardStudying.studyTimeRequired; debug("island studied");
		default:debug("No more next steps");
	}

	DEBUG.QUICK_BUTTON_INDEX++;
}