////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                               OpenCollar - main                                //
//                                 version 3.970                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.  ->  www.opencollar.at/license.html  //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2014  Individual Contributors and OpenCollar - submission set free™ //
// ------------------------------------------------------------------------------ //
//                    github.com/OpenCollar/OpenCollarUpdater                     //
// ------------------------------------------------------------------------------ //
////////////////////////////////////////////////////////////////////////////////////

//on start, send request for submenu names
//on getting submenu name, add to list if not already present
//on menu request, give dialog, with alphabetized list of submenus
//on listen, send submenu link message

string g_sCollarVersion="3.9.82";   //FIXME: symantic version numbers need extra code to support
integer g_iLatestVersion=TRUE;

list g_lOwners;
key g_kWearer;
string g_sOldRegionName;
list g_lMenuPrompts;
    

list g_lMenuIDs;//3-strided list of avatars given menus, their dialog ids, and the name of the menu they were given
integer g_iMenuStride = 3;

integer g_iScriptCount;//when the scriptcount changes, rebuild menus

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

//5000 block is reserved for IM slaves

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";
string GIVECARD = "Quick Guide";
string HELPCARD = "OpenCollar Guide";
string CONTACT = "Contact";
string LICENSE="License";
key webLookup;
key webRequester;

list g_lAppsButtons;

integer g_iLocked = FALSE;
integer g_bDetached = FALSE;
integer g_iHide ; // global hide
integer g_iNews=TRUE;

//integer g_iTraceOn = FALSE;

string g_sLockPrimName="Lock"; // Description for lock elements to recognize them //EB //SA: to be removed eventually (kept for compatibility)
string g_sOpenLockPrimName="OpenLock"; // Prim description of elements that should be shown when unlocked
string g_sClosedLockPrimName="ClosedLock"; // Prim description of elements that should be shown when locked
list g_lClosedLockElements; //to store the locks prim to hide or show //EB
list g_lOpenLockElements; //to store the locks prim to hide or show //EB

string LOCK = " LOCK";
string UNLOCK = " UNLOCK";
string CTYPE="collar";
string g_sDefaultLockSound="caa78697-8493-ead3-4737-76dcc926df30";
string g_sDefaultUnlockSound="ff09cab4-3358-326e-6426-ec8d3cd3b98e";
string g_sLockSound="caa78697-8493-ead3-4737-76dcc926df30";
string g_sUnlockSound="ff09cab4-3358-326e-6426-ec8d3cd3b98e";

integer g_iAnimsMenu=FALSE;
integer g_iRlvMenu=FALSE;
integer g_iAppearanceMenu=FALSE;
integer g_iCustomizeMenu=FALSE;

integer g_iUpdateChan = -7483214;
integer g_iUpdateHandle;

key g_kConfirmUpdate;
key g_kUpdaterOrb;
integer g_iUpdateFromMenu;

// We check for the latest version number by looking at the "~version" notecard
// inside the 'release' branch of the collar's Github repo.
string version_check_url = "https://raw.githubusercontent.com/OpenCollar/OpenCollarUpdater/main/LSL/~version";
key github_version_request;

// A request to this URL will trigger delivery of an updater.  We omit the
// "version=blah" parameter because we don't want the server deciding whether
// we should get an updater or not.  We just want one.
//string delivery_url = "http://update.mycollar.org/updater/check?object=OpenCollarUpdater&update=yes";
//key appengine_delivery_request;

// The news system is back!  Only smarter this time.  News will be kept in a
// static file on Github to keep server load down.  This script will remember
// the date of the last time it reported news so it will only show things once.
// It will also not show things more than a week old.
string news_url = "https://raw.githubusercontent.com/OpenCollar/OpenCollarUpdater/main/LSL/~news";
key news_request;
key news_now;

key g_kUpdateRequest;

// store versions as strings and don't cast to float until the last minute.
// This ensures that we can display them in a nice way without a bunch of
// floating point garbage on the end.
string my_version = "0.0";
key my_version_request;

key g_kUpdater; // key of avi who asked for the update
integer g_iUpdateAuth;
integer g_iUpdatersNearBy = -1;
integer g_iWillingUpdaters = -1;

string last_news_time = "0";

string g_sUpdaterName="OpenCollar Updater";
string g_sRelease_version;
string g_sHowToUpdate="Get an Updater at http://maps.secondlife.com/secondlife/Haven%20VI/231/27/21\nhttps://www.primbay.com/product.php?id=1782591\nhttps://marketplace.secondlife.com/p/OpenCollar-Updater/5493698 or any OpenCollar network vendor."; //put in appropriate message here.



//Debug(string text){llOwnerSay(llGetScriptName() + ": " + text);}

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) { //we've alread given a menu to this user.  overwrite their entry
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    } else { //we've not already given this user a menu. append to list
        g_lMenuIDs += [kID, kMenuID, sName];
    }
} 

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

AppsMenu(key kID, integer iAuth) {
    string sPrompt="\nBrowse apps, extras and custom features.\n\nwww.opencollar.at/apps";
    sPrompt+="\nmax memory used: "+(string)llGetSPMaxMemory();
    list lUtility = [UPMENU];
    //string sTraceButton="☐ Trace";
    //if () sTraceButton="☒ Trace";
    //Dialog(kID, sPrompt, sTraceButton+g_lAppsButtons, lUtility, 0, iAuth, "Apps");
    Dialog(kID, sPrompt, g_lAppsButtons, lUtility, 0, iAuth, "Apps");
}
HelpMenu(key kID, integer iAuth) {
    string sPrompt="\nOpenCollar Version "+g_sCollarVersion+"\n";
    if(!g_iLatestVersion) sPrompt+="Update available!";
    sPrompt+= "\n\nThe OpenCollar stock software bundle in this item is licensed under the GPLv2 with additional requirements specific to Second Life®.\n\n© 2008 - 2014 Individual Contributors and\nOpenCollar - submission set free™\n\nwww.opencollar.at/helpabout";
    sPrompt+="\nmax memory used: "+(string)llGetSPMaxMemory();
    list lUtility = [UPMENU];
    
    string sNewsButton="☐ News";
    if (g_iNews){
        sNewsButton="☒ News";
    }
    list lStaticButtons=[GIVECARD,CONTACT,LICENSE,sNewsButton,"Update","Settings"];
    Dialog(kID, sPrompt, lStaticButtons, lUtility, 0, iAuth, "Help/About");
}
MainMenu(key kID, integer iAuth) {
    string sPrompt="\nOpenCollar Version "+g_sCollarVersion+"\nwww.opencollar.at/main-menu";
    sPrompt+="\nmax memory used: "+(string)llGetSPMaxMemory();
    list lStaticButtons=["Apps"];
    if (g_iAnimsMenu){
        lStaticButtons+="Animations";
    } else {
        lStaticButtons+=" ";
    }
    if (g_iCustomizeMenu){
        lStaticButtons+="Customize";
    } else if (g_iAppearanceMenu){
        lStaticButtons+="Appearance";
    } else {
        lStaticButtons+=" ";
    }
    lStaticButtons+=["Leash"];
    if (g_iRlvMenu){
        lStaticButtons+="RLV";
    } else {
        lStaticButtons+=" ";
    }
    lStaticButtons+=["Access","Extras","Help/About"];
    
    if (g_iLocked) Dialog(kID, sPrompt, UNLOCK+lStaticButtons, [], 0, iAuth, "Main");
    else Dialog(kID, sPrompt, LOCK+lStaticButtons, [], 0, iAuth, "Main");
}

ConfirmUpdate(key kID, integer iAuth)
{
    //string sPrompt = "\n\nDo you want to update with " + llKey2Name(kUpdater) + " with object key:\n\n" + (string)kUpdater +"\n"
    string sPrompt = "\n3 Golden Rules for Updates:\n\n1.Create a Backup\n2.Rezzed is safer than Worn\n3.Low Lag regions make happy Updates\n\n(These rules apply to any kind of scripted item, not just collars or bondage and kink items!)\n\nATTENTION: Do not rez any other collars till the update has started.\n\nReady?";

    sPrompt+="\nmax memory used: "+(string)llGetSPMaxMemory();

    Dialog(kID, sPrompt, ["Yes", "No"], [], 0, iAuth, "ConfirmUpdate");
}

integer UserCommand(integer iNum, string sStr, key kID, integer fromMenu) {
    if (iNum == COMMAND_EVERYONE) return TRUE;  // No command for people with no privilege in this plugin.
    else if (iNum > COMMAND_EVERYONE || iNum < COMMAND_OWNER) return FALSE; // sanity check


    list lParams = llParseString2List(sStr, [" "], []);
    string sCmd = llList2String(lParams, 0);

    sCmd=llToLower(sCmd);

    if (sStr == "menu") MainMenu(kID, iNum);
    else if (sCmd == "menu") {
        string sSubmenu = llGetSubString(sStr, 5, -1);
        if (sSubmenu == "Main"){
            MainMenu(kID, iNum);
        } else if (sSubmenu == "Apps" || sSubmenu=="AddOns"){
            AppsMenu(kID, iNum);
        } else if (sSubmenu == "Help/About"){
            HelpMenu(kID, iNum);
        }
    } else if (sStr == "license") {
        if(llGetInventoryType("OpenCollar License")==INVENTORY_NOTECARD) llGiveInventory(kID,"OpenCollar License");
        else Notify(kID,"License notecard missing from collar, sorry.", FALSE); 
    } else if (sStr == "help") llGiveInventory(kID, HELPCARD); 
    else if (sStr =="about" || sStr=="help/about") HelpMenu(kID,iNum);               
    else if (sStr == "addons" || sStr=="apps") AppsMenu(kID, iNum);
    else if (sCmd == "menuto") {
        key kAv = (key)llList2String(lParams, 1);
        if (llGetAgentSize(kAv) != ZERO_VECTOR) //if kAv is an avatar in this region
        {
            if(llGetOwnerKey(kID)==kAv) MainMenu(kID, iNum);    //if the request was sent by something owned by that agent, send a menu
            else  llMessageLinked(LINK_SET, COMMAND_NOAUTH, "menu", kAv);   //else send an auth request for the menu
        }
    } else if (sCmd == "lock" || (!g_iLocked && sStr == "togglelock")) {
        //Debug("User command:"+sCmd);

        if (iNum == COMMAND_OWNER || kID == g_kWearer ) {   //primary owners and wearer can lock and unlock. no one else
            //inlined old "Lock()" function        
            g_iLocked = TRUE;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "Global_locked=1", "");
            llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
            llPlaySound(g_sLockSound, 1.0);
            SetLockElementAlpha();//EB

            Notify(kID, "Locked.", FALSE);
            if (kID!=g_kWearer) llOwnerSay("Your " + CTYPE + " has been locked.");
        }
        else Notify(kID, "Sorry, only primary owners and wearer can lock the " + CTYPE + ".", FALSE);
    }
    else if (sStr == "runaway" || sCmd == "unlock" || (g_iLocked && sStr == "togglelock"))
    {
        if (iNum == COMMAND_OWNER)  {  //primary owners can lock and unlock. no one else
            //inlined old "Unlock()" function
            g_iLocked = FALSE;
            llMessageLinked(LINK_SET, LM_SETTING_DELETE, "Global_locked", "");
            llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
            llPlaySound(g_sUnlockSound, 1.0);
            SetLockElementAlpha(); //EB

            Notify(kID, "Unlocked.", FALSE);
            if (kID!=g_kWearer) Notify(g_kWearer,"Your " + CTYPE + " has been unlocked.",FALSE);
        }
        else Notify(kID, "Sorry, only primary owners can unlock the " + CTYPE + ".", FALSE);
    } else if (sCmd == "fixmenus") {
        if (kID == g_kWearer){
            RebuildMenu();
            Notify(kID, "Rebuilding menus, this may take several seconds.", FALSE);
            if (fromMenu) MainMenu(kID, iNum);
        }
    } else if (sCmd == "news"){
        if (kID == g_kWearer){
            if (sStr=="news off"){
                g_iNews=FALSE;
                //notify news off
                Notify(kID,"News items will no longer be downloaded from the OpenCollar web site.",TRUE);
            } else if (sStr=="news on"){
                g_iNews=TRUE;
                //notify news on
                Notify(kID,"News items will be downloaded from the OpenCollar web site when they are available.",TRUE);
                news_now = llHTTPRequest(news_url, [HTTP_METHOD, "GET"], "");
            } else {
                news_now = llHTTPRequest(news_url, [HTTP_METHOD, "GET"], "");
            }
        } else {
            //notify only wearer and owner can change news settings
            Notify(kID,"Only primary owners and wearer can change news settings.",FALSE);
        }
    } else if (sCmd == "update") {
        if (kID == g_kWearer) {
            string sVersion = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 1);
            g_iUpdatersNearBy = 0;
            g_iWillingUpdaters = 0;
            g_kUpdater = kID;
            g_iUpdateAuth = iNum;
            Notify(kID,"Searching for nearby updater",FALSE);
            g_iUpdateHandle = llListen(g_iUpdateChan, "", "", "");
            g_iUpdateFromMenu=fromMenu;
            llWhisper(g_iUpdateChan, "UPDATE|" + sVersion);
            llSetTimerEvent(10.0); //set a timer to close the g_iListener if no response
        } else {
            Notify(kID,"Only the wearer can update the " + CTYPE + ".",FALSE);
        }
    } else if (sCmd == "version") {
        Notify(kID, "I am running OpenCollar version " + my_version, FALSE);
    } else if (sCmd == "objectversion") {
        // ping from an object, we answer to it on the object channel
        
        // inlined single use GetOwnerChannel(key kOwner, integer iOffset) function
        integer iChan = (integer)("0x"+llGetSubString((string)g_kWearer,2,7)) + 1111;
        if (iChan>0) iChan=iChan*(-1);
        if (iChan > -10000) iChan -= 30000;

        llSay(iChan,(string)g_kWearer+"\\version="+my_version);
    }
    return TRUE;
}

NotifyOwners(string sMsg) {
    integer n;
    integer stop = llGetListLength(g_lOwners);
    for (n = 0; n < stop; n += 2) {
        Notify((key)llList2String(g_lOwners, n), sMsg, FALSE);
    }
}

string GetTimestamp() { // Return a string of the date and time
    string out;
    string DateUTC = llGetDate();
    if (llGetGMTclock() < 28800) { // that's 28800 seconds, a.k.a. 8 hours.
        list DateList = llParseString2List(DateUTC, ["-", "-"], []);
        integer year = llList2Integer(DateList, 0);
        integer month = llList2Integer(DateList, 1);
        integer day = llList2Integer(DateList, 2);
       // day = day - 1; //Remember, remember, the 0th of November!
       if(day==1) {
           if(month==1) return (string)(year-1) + "-01-31";
           else {
                --month;
                if(month==2) day = 28+(year%4==FALSE); //To do: fix before 28th feb 2100.
                else day = 30+ (!~llListFindList([4,6,9,11],[month])); //31 days hath == TRUE
            }
        }
        else --day;
        out=(string)year + "-" + (string)month + "-" + (string)day;
    } else out=llGetDate();
    
    integer t = (integer)llGetWallclock(); // seconds since midnight
    out += " " + (string)(t / 3600) + ":";
    
    integer mins=(t % 3600) / 60;
    if (mins <10){
        out += "0";
    }
    out += (string)mins+":";

    integer secs=t % 60;
    if (secs < 10){
        out += "0";
    }
    out += (string)secs;
    
    return out;
}

BuildLockElementList()//EB
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    list lParams;

    // clear list just in case
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        // read description
        lParams=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        // check inf name is lock name
        if (llList2String(lParams, 0)==g_sLockPrimName || llList2String(lParams, 0)==g_sClosedLockPrimName)
        {
            // if so store the number of the prim
            g_lClosedLockElements += [n];
        }
        else if (llList2String(lParams, 0)==g_sOpenLockPrimName) 
        {
            // if so store the number of the prim
            g_lOpenLockElements += [n];
        }
    }
}

SetLockElementAlpha() //EB
{
    if (g_iHide) return ; // ***** if collar is hide, don't do anything 
    //loop through stored links, setting alpha if element type is lock
    integer n;
    //float fAlpha;
    //if (g_iLocked) fAlpha = 1.0; else fAlpha = 0.0; //Let's just use g_iLocked!
    integer iLinkElements = llGetListLength(g_lOpenLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,n), !g_iLocked, ALL_SIDES);
    }
    iLinkElements = llGetListLength(g_lClosedLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,n), g_iLocked, ALL_SIDES);
    }
}

RebuildMenu()
{
    //Debug("Rebuild Menu");
    g_iAnimsMenu=FALSE;
    g_iRlvMenu=FALSE;
    g_iAppearanceMenu=FALSE;
    g_lAppsButtons = [] ;
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Main", "");
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "AddOns", "");
    llMessageLinked(LINK_SET, MENUNAME_REQUEST, "Apps", "");
}

default
{
    state_entry() {
        //llOwnerSay("Main: state entry:"+(string)llGetFreeMemory());
        g_kWearer = llGetOwner();
        BuildLockElementList();
        llSleep(1.0);//delay sending this message until we're fairly sure that other scripts have reset too, just in case
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "collarversion", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "Global_locked", "");
        //llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "Global_trace", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "auth_owner", "");
        g_iScriptCount = llGetInventoryNumber(INVENTORY_SCRIPT);
        RebuildMenu();
        
        if (g_iNews) news_request = llHTTPRequest(news_url, [HTTP_METHOD, "GET"], "");
        github_version_request = llHTTPRequest(version_check_url, [HTTP_METHOD, "GET"], "");
        llScriptProfiler(PROFILE_SCRIPT_MEMORY);
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        // SA: delete this after transition is finished
        if (iNum == COMMAND_NOAUTH) return;
        // /SA
        else if (iNum == MENUNAME_RESPONSE) {
            //sStr will be in form of "parent|menuname"
            list lParams = llParseString2List(sStr, ["|"], []);
            string sName = llList2String(lParams, 0);
            string sSubMenu = llList2String(lParams, 1);
            if (sName=="AddOns" || sName=="Apps"){  //we only accept buttons for apps nemu
                //Debug("we handle " + sName);
                if (llListFindList(g_lAppsButtons, [sSubMenu]) == -1) {
                    g_lAppsButtons += [sSubMenu];
                    g_lAppsButtons = llListSort(g_lAppsButtons, 1, TRUE);
                }
            } else if (sStr=="Main|Animations"){
                g_iAnimsMenu=TRUE;
            } else if (sStr=="Main|RLV"){
                g_iRlvMenu=TRUE;
            } else if (sStr=="Main|Appearance"){
                g_iAppearanceMenu=TRUE;
            } else if (sStr=="Main|Customize"){
                g_iCustomizeMenu=TRUE;
            }
        } else if (iNum == MENUNAME_REMOVE) {
            //sStr should be in form of parentmenu|childmenu
            list lParams = llParseString2List(sStr, ["|"], []);
            string parent = llList2String(lParams, 0);
            string child = llList2String(lParams, 1);

            if (parent=="Apps" || parent=="AddOns")
            {
                integer gutiIndex = llListFindList(g_lAppsButtons, [child]);
                //only remove if it's there
                if (gutiIndex != -1) g_lAppsButtons = llDeleteSubList(g_lAppsButtons, gutiIndex, gutiIndex);
            }
        } else if (iNum == DIALOG_RESPONSE) {
            //Debug("Menu response");
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                                         
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                
                
                //process response
                if (sMenu=="Main"){
                    //Debug("Main menu response: '"+sMessage+"'");
                    if (sMessage == LOCK || sMessage== UNLOCK){
                        //Debug("doing usercommand for '"+sMessage+"' from "+sMenu+" menu");
                        UserCommand(iAuth, sMessage, kAv, TRUE);
                        MainMenu(kAv, iAuth);
                    } else if (sMessage == "Help/About"){
                        HelpMenu(kAv, iAuth);
                    } else if (sMessage == "Apps"){
                        AppsMenu(kAv, iAuth);
                    } else {
                        //Debug("doing link message for 'menu "+sMessage+"' button from Apps menu");
                        llMessageLinked(LINK_SET, iAuth, "menu "+sMessage, kAv);
                    }
                } else if (sMenu=="Apps"){
                    //Debug("Apps menu response:"+sMessage);
                    if (sMessage == UPMENU) {
                        MainMenu(kAv, iAuth);
/*
                    } else if (sMessage=="☐ Trace") {
                        //Debug("Trace off button");    
                        UserCommand(iAuth, "trace on", kAv, TRUE);
                        AppsMenu(kAv, iAuth);
                    } else if (sMessage=="☒ Trace") {
                        //Debug("Trace off button");    
                        UserCommand(iAuth, "trace off", kAv, TRUE);
                        AppsMenu(kAv, iAuth);
*/
                    } else {
                        //Debug("doing link message for 'menu "+sMessage+"' button from Apps menu");
                        llMessageLinked(LINK_SET, iAuth, "menu "+sMessage, kAv);
                    }
                } else if (sMenu=="ConfirmUpdate"){
                    if (sMessage == "Yes") {
                        //inlined single use SayUpdatePin(g_kUpdaterOrb); function
                        integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
                        llSetRemoteScriptAccessPin(pin);
                        llRegionSayTo(g_kUpdaterOrb, g_iUpdateChan, "ready|" + (string)pin ); //give the ok to send update sripts etc...
                    } else {
                        HelpMenu(kAv, iAuth);
                    }
                } else if (sMenu=="Help/About"){
                    //Debug("Help menu response");
                    if (sMessage == UPMENU) MainMenu(kAv, iAuth);
                    else if (sMessage == "Settings") {
                        llMessageLinked(LINK_SET, iAuth, "menu settings", kAv);
                    } else if (sMessage == GIVECARD) {
                        UserCommand(iAuth,"help",kAv, TRUE);
                        HelpMenu(kAv, iAuth);
                    } else if (sMessage == LICENSE) {
                        UserCommand(iAuth,"license",kAv, TRUE);
                        HelpMenu(kAv, iAuth);
                    } else if (sMessage == CONTACT) {
                        webLookup = llHTTPRequest("https://raw.githubusercontent.com/OpenCollar/OpenCollarUpdater/main/LSL/~contact", [HTTP_METHOD, "GET"], "");
                        webRequester = kAv;
                        HelpMenu(kAv, iAuth);
                    } else if (sMessage=="☐ News") {
                        //Debug("News on button");    
                        UserCommand(iAuth, "news on", kAv, TRUE);
                        HelpMenu(kAv, iAuth);
                    } else if (sMessage=="☒ News") {
                        //Debug("News off button");    
                        UserCommand(iAuth, "news off", kAv, TRUE);
                        HelpMenu(kAv, iAuth);
                    } else if (sMessage == "Update") llMessageLinked(LINK_SET, iAuth, "update remenu", kAv);
                    //else if (sMessage == "Get Updater") llMessageLinked(LINK_SET, iAuth, "menu Get Updater", kAv);
                    //else //Debug("Unknown button:'"+sMessage+"'");
                }
            }
        }
        else if (UserCommand(iNum, sStr, kID, FALSE)) return;
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if(sToken == "collarversion")
            {
                g_sCollarVersion=llList2String(lParams,1);
                g_iLatestVersion=(integer)llList2String(lParams,2);
            }
            else if (sToken == "Global_locked")
            {
                g_iLocked = (integer)sValue;
                SetLockElementAlpha(); //EB

            }
            else if (sToken == "Global_CType") CTYPE = sValue;
            else if (sToken == "auth_owner")
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
            else if(sToken =="lock_locksound")
            {
                if(sValue=="default") g_sLockSound=g_sDefaultLockSound;
                else if((key)sValue!=NULL_KEY || llGetInventoryType(sValue)==INVENTORY_SOUND) g_sLockSound=sValue;
            }
            else if(sToken =="lock_unlocksound")
            {
                if(sValue=="default") g_sUnlockSound=g_sDefaultUnlockSound;
                else if((key)sValue!=NULL_KEY || llGetInventoryType(sValue)==INVENTORY_SOUND) g_sUnlockSound=sValue;
            }
            else if (sToken == "Global_news") g_iNews = (integer)sValue;

/*
            else if(sToken =="Global_trace")
            {
                g_iTraceOn = (integer)sValue;
            }
*/
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            //remove stride from g_lMenuIDs
            //we have to subtract from the index because the dialog id comes in the middle of the stride
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                        
        }
        else if (iNum == LM_SETTING_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "auth_owner")
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
        }
        else if (iNum == RLV_REFRESH || iNum == RLV_CLEAR)
        {
            if (g_iLocked) llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
            else llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
    
    changed(integer iChange)
    {
        if (iChange & CHANGED_INVENTORY)
        {
            if (llGetInventoryNumber(INVENTORY_SCRIPT) != g_iScriptCount)
            {//a script has been added or removed.  Reset to rebuild menu
                RebuildMenu(); //llResetScript();
            }
        }
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
        if (iChange & CHANGED_COLOR) // ********************* 
        {
            integer iNewHide=!(integer)llGetAlpha(ALL_SIDES) ; //check alpha
            if (g_iHide != iNewHide){   //check there's a difference to avoid infinite loop
                g_iHide = iNewHide;
                SetLockElementAlpha(); // update hide elements 
            }
        }
        if (iChange & CHANGED_LINK) BuildLockElementList(); // need rebuils lockelements list
/*
        if (iChange & CHANGED_TELEPORT || iChange & CHANGED_REGION){
            if (g_iTraceOn){
                string sRegionName=llGetRegionName();
                if (sRegionName != g_sOldRegionName){
                    g_sOldRegionName=sRegionName;
                    vector vPos=llGetPos();
                    string sName=llGetUsername(g_kWearer);
                    integer iIndex=llSubStringIndex(sName,"Resident");
                    if (iIndex > -1){
                        sName=llGetSubString(sName,0,iIndex-1);
                    }
                    string sSlurl="http://maps.secondlife.com/secondlife/"+llEscapeURL(sRegionName)+"/"+(string)llFloor(vPos.x)+"/"+(string)llFloor(vPos.y)+"/"+(string)llFloor(vPos.z);
                    
                    NotifyOwners(sName + " arrives at " +sSlurl);
                }
            }
        }
*/
    }
    attach(key kID)
    {
        if (g_iLocked)
        {
            if(kID == NULL_KEY)
            {
                g_bDetached = TRUE;
                NotifyOwners(llKey2Name(g_kWearer) + " has detached me while locked at " + GetTimestamp() + "!");
            }
            else if(g_bDetached)
            {
                NotifyOwners(llKey2Name(g_kWearer) + " has re-atached me at " + GetTimestamp() + "!");
                g_bDetached = FALSE;
            }
        }
    }
    http_response(key id, integer status, list meta, string body){
        if (status == 200) { // be silent on failures.
            if (id == webLookup){
                Notify(webRequester,body,FALSE);
            }
        } else if (id == github_version_request) {
            // strip the newline off the end of the text
            g_sRelease_version = llGetSubString(body, 0, -2);
            //Deg_sRelease_versionbug("release:"+release_version);
            if ((float)g_sRelease_version > (float)my_version)
            {
                string prompt = "\n\nYou are running OpenCollar version " +
                my_version + ".  There is an update available.\n"+g_sHowToUpdate;
                llDialog(llGetOwner(),prompt,["Ok!"],-23426245);
                
               // g_kMenuID = Dialog(wearer, prompt, [BTN_GET_UPDATE], ["Cancel"], 0, COMMAND_WEARER);
               llMessageLinked(LINK_THIS,LM_SETTING_RESPONSE,"collarversion="+(string)my_version+"=0","");
            }
            else llMessageLinked(LINK_THIS,LM_SETTING_RESPONSE,"collarversion="+(string)my_version+"=1","");
        }
        else if (id == g_kUpdateRequest){
            Notify(g_kUpdater,body,FALSE);
        }
        else if (id == news_now){
            //Debug("Got news_now");
            Notify(g_kUpdater,body,FALSE);
        }
        else if (id == news_request)
        {
            // We got a response back from the news page on Github.  See if
            // it's new enough to report to the user.
            string firstline = llList2String(llParseString2List(body, ["\n"], []), 0);
            list firstline_parts = llParseString2List(firstline, [" "], []);
            
            // The first line of a news item should always look like this:
            // # First News - 20111012
            // or optionally with a decimal like this:
            // # Second News of the Day - 20111012.2
            // So we can compare timestamps that way.  
            string this_news_time = llList2String(firstline_parts, -1);

            if ((integer)last_news_time > (integer)this_news_time) {
                string news = "Newsflash " + body;
                Notify(llGetOwner(), news, FALSE);
                // last news time is remembered in memory.  We used to
                // store it in the desc but you can't write to that while
                // worn.
                last_news_time = this_news_time;
            } 
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {   //collar and updater have to have the same Owner else do nothing!
        //Debug(message);
        if (llGetOwnerKey(id) == g_kWearer)
        {
            list lTemp = llParseString2List(message, [","],[]);
            string sCommand = llList2String(lTemp, 0);
            if(message == "nothing to update")
            {
                g_iUpdatersNearBy++;
            }
            else if( message == "get ready")
            {
                g_iUpdatersNearBy++;
                g_iWillingUpdaters++;
                //g_kUpdaterOrb = id;
                ConfirmUpdate(g_kWearer,COMMAND_WEARER); 
                g_iUpdatersNearBy = -1;
                g_iWillingUpdaters = -1;
                llSetTimerEvent(0);
            }
        }
    }

    timer()
    {
        //Debug("timer");
        llSetTimerEvent(0.0);
        llListenRemove(g_iUpdateHandle);
        if (g_iUpdatersNearBy > -1)
        {
            if (!g_iUpdatersNearBy)
            {
                //Notify(g_kUpdater,"No updaters found.  Please rez an updater within 10m and try again",FALSE);
                g_kUpdateRequest = llHTTPRequest("https://raw.githubusercontent.com/OpenCollar/OpenCollarUpdater/main/LSL/~update", [HTTP_METHOD, "GET"], "");
                if (g_iUpdateFromMenu) HelpMenu(g_kUpdater,g_iUpdateAuth);
                //else Debug("Not remenuing");
            }
            else if (g_iWillingUpdaters > 1)
            {
                Notify(g_kUpdater,"Multiple updaters were found within 10m.  Please remove all but one and try again",FALSE);
            }
            g_iUpdatersNearBy = -1;
            g_iWillingUpdaters = -1;
        }
    }
}