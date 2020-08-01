/**
 * ================================================
 * 			Drage Ander Island
 * 			Dragon Spirits Island
 *
 * The player must discover the secrets of the island before the island is consumed by spirits.
 * What choices will you make? Can you discover all three endings?
 * ================================================
 */

var human:Player;

var START_ZONE_ID: Int = 65;
var MYSTERY_ZONE_ID: Int = 8;
var GRAVEYARD_ZONE_ID: Int = 72;
var PORT_ZONE_ID: Int = 39;
var LORE_CIRCLE_ZONE_IDS = [41, 45];
var KOBOLD_HOME_TILE_ID: Int = 53;
var STARTER_CARVED_STONE_TILE_ID: Int = 76;

var PRIMARY_OBJ_ID = "primaryobjid";
var NONE_FORMAT = "NONE";

var DIALOG_SUPPRESS_ID = "dialogsuppressid";
var DIALOG_SUPPRESSED:Bool = false; // The player can choose to skip the dialog in the opening. This makes replays less annoying
var DIALOG_SUPPRESSED_TIMEOUT:Int = 60;

var TIME_TO_OPENING_DIALOG:Int = 15;

var SPIRIT_DATA = {

};

var DIALOG = {
	opening:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"We have setup camp here on the center of the island. I can't wait to discover what is so mysterious here."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"We have very little to go on. All we know is most ships can't even land before the fog gets too dense."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Yes, that fog and wind nearly blew us off course. Barely managed to keep the ship going straight."},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Let's start expanding and see what we can discover..."},
	],

	initial_explore:[
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Do you feel the sensation that we just don't...belong? I have felt unwanted on many Lore hunts before, but not like this"},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"I feel something more. The spirits here have a high energy, yet are calm. Or maybe highly focused. I can't explain it."},
	],

	spirit_appears:[
		{option:{who:Banner.Giant1, name:"Restless Spirits"}, text:"YoU daRE to DIstuRb ANDER DRAGE Island? YoU were wArDED awaY, yeT HErE yoU ArE."},
		{option:{who:Banner.Giant1, name:"Restless Spirits"}, text:"Go bAck. NevER retUrn...."},
		{option:{who:Banner.Giant1, name:"Restless Spirits"}, text:"it aWakENs......"},
		{option:{who:Banner.Giant1, name:"Restless Spirits"}, text:"BEGONE!"},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"The spirits, their energy is changing. It is bubbling and churning. I fear the island's spiritual world is trying to merge with ours!"},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"Then we need to quickly figure out this mystery. I don't think that will be the last of the spirits we see."},
	],

	starter_stone:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"Hmm, this Lore Stone is unlike others I have seen. We should study it more."},
	],

	starter_stone_studied:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"We got some information from the stone. Of what we can recover, there was some kind of shipping, or port?, to the North."},
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"The South is more interesting, maybe. It indicates some kind of mass burial"},
		{option:{who:Banner.BannerGoat, name:"Halvard"}, text:"We should investigate the South first, there might be more there to learn."},
	],

	graveyard_study_start:[
		{option:{who:Banner.BannerBoar, name:"Svarn"}, text:"This graveyard site is a gold mine of knowledge! If only we could spend more time digging."},
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

	],
};

var starterStone = {
	firstAssign:true,
	studiedTime:0.0,
	studyTimeRequired:120,
	studied:false,
	studiersRequired:1,
	zoneIds:[STARTER_CARVED_STONE_TILE_ID],
	startDialog:DIALOG.starter_stone,
	finishDialog:DIALOG.starter_stone_studied,
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
}

/**
 * Required function, called automatically by the game engine.
 */
function init() {
	if (state.time == 0)
		onFirstLaunch();
}

function onFirstLaunch() {

	// Disabled events. We shall send our own >:)
	noEvent();

	// I would use me(), but the Editor thinks it is broken even though it works,
	// but then it won't show any other errors :(
	debug("getting human");
	human = getZone(START_ZONE_ID).owner;
	var hall = human.getTownHall();
	summonWarchief(human, getZone(START_ZONE_ID), hall.x + 7, hall.y + 7);

	debug("setting up obj");
	setupObjectives();

	human.discoverZone(getZone(STARTER_CARVED_STONE_TILE_ID)); // TODO FOR TESTING
}

/**
 * Required function, called automatically by the game engine.
 */
function regularUpdate(dt : Float) {

	checkObjectives();

	checkDialog();

	checkStudying();

	checkSpirits();

	if(toInt(state.time) % 10 == 0)
		debug("running...");
}

/**
 * Manages updating the progress and visibility of all the objectives.
 */
function checkObjectives() {

	if(state.objectives.isVisible(DIALOG_SUPPRESS_ID) && state.time > DIALOG_SUPPRESSED_TIMEOUT) {
		state.objectives.setVisible(DIALOG_SUPPRESS_ID, false);
	}
}

/**
 * Manages sending dialog to the player at certain times or under certain conditions the player triggers
 */
function checkDialog() {
	if(DIALOG.opening.length > 0 && TIME_TO_OPENING_DIALOG < state.time) {
		debug("Opening dialog shown");
		pauseAndShowDialog(DIALOG.opening);
		DIALOG.opening = [];
	}

	if(DIALOG.initial_explore.length > 0 && human.discovered.length == 2) {
		debug("Initial explore dialog shown");
		pauseAndShowDialog(DIALOG.initial_explore);
		state.objectives.setVisible(PRIMARY_OBJ_ID, true);
		DIALOG.initial_explore = [];
	}

	if(DIALOG.spirit_appears.length > 0 && human.discovered.length == 4) {
		debug("Spirit Appears dialog shown");
		pauseAndShowDialog(DIALOG.spirit_appears);
		DIALOG.spirit_appears = [];
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
}

/**
 * This does the work of managing the progress of each lore site. Dialog is triggered upon
 * first study and upon completion.
 */
function checkStudyingProgress(tracker) {

	// checking number of units on a tile is expensive (esp if lots of units are in the tile, or multiple tiles)
	// We don't want to incur that cost if the current objective is already finished
	if(tracker.studied)
		return;

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
			tracker.studiersRequired == units ? 0.5 : 0.7;
	}

	if(!tracker.studied && tracker.studiedTime > tracker.studyTimeRequired) {
		tracker.studied = true;
		pauseAndShowDialog(tracker.finishDialog);
	}
}

/**
 * Spirits will act against the player, with typically more and more pressure the further
 * the player is in the quest. Pressure will also be applied if the player takes too long,
 * so as to prevent turtling before the objective gets triggered.
 */
function checkSpirits() {

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


/**
 * ======================================================
 * 		At the time of this mod, the Editor is suuuuper buggy and will think things don't exist that do.
 * 		They are shoved at the bottom so other errors have a chance to show up above. Only one error is shown
 * 		at a time, and only top-down.
 * ======================================================
 */

/**
 * A helper function to show multiple lines of text.
 */
function pauseAndShowDialog(dialog) {
	if(!DIALOG_SUPPRESSED) {
		setPause(true);
		for(d in dialog) {
			talk(d.text, d.option); // editor doesn't understand talk
		}
		setPause(false);
	}
}

function setupObjectives() {
	state.objectives.add(PRIMARY_OBJ_ID, "Discover the Secret of the Isle", {visible:false});
	state.objectives.add(DIALOG_SUPPRESS_ID, "Disable dialog", {visible:true}, {name:"Disable", action:"disableDialogCallback"}); // the editor doesn't understand buttons
}