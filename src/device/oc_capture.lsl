
//  oc_capture.lsl
//
//  Copyright (c) 2014 - 2016 littlemousy, Sumi Perl, Wendy Starfall,
//  Garvin Twine
//
//  This script is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published
//  by the Free Software Foundation, version 2.
//
//  This script is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this script; if not, see www.gnu.org/licenses/gpl-2.0

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

integer g_iBuild = 22;

key g_kWearer;

list g_lMenuIDs;

integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_SAFEWORD = 510;

integer NOTIFY = 1002;
integer SAY = 1004;
integer REBOOT = -1000;
integer LINK_AUTH = 2;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer BUILD_REQUEST = 17760501;

string  g_sTempOwnerID;
integer g_iRiskyOn;
integer g_iCaptureOn;
integer g_iCaptureInfo = TRUE;
string  g_sSettingToken = "capture_";

string NameURI(string sID){
    return "secondlife:///app/agent/"+sID+"/about";
}

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sMenu, key kCaptor) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sMenu, kCaptor], iIndex, iIndex + 3);
    else g_lMenuIDs += [kID, kMenuID, sMenu, kCaptor];
}

CaptureMenu(key kId, integer iAuth) {
    string sPrompt = "\nCapture";
    list lMyButtons;
    if (g_sTempOwnerID) lMyButtons += "Release";
    else {
        if (g_iCaptureOn) lMyButtons += "OFF";
        else lMyButtons += "ON";

        if (g_iRiskyOn) lMyButtons += "☑ risky";
        else lMyButtons += "☐ risky";
    }
    if (g_sTempOwnerID)
        sPrompt += "\n\nCaptured by: "+NameURI(g_sTempOwnerID);
    Dialog(kId, sPrompt, lMyButtons, ["BACK"], 0, iAuth, "CaptureMenu", "");
}

saveTempOwners() {
    if (g_sTempOwnerID) {
        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "auth_tempowner="+g_sTempOwnerID, "");
        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "auth_tempowner="+g_sTempOwnerID, "");
    } else {
        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "auth_tempowner=", "");
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, "auth_tempowner", "");
    }
}

doCapture(string sCaptorID, integer iIsConfirmed) {
    if (g_sTempOwnerID) {
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%WEARERNAME% is already captured, try another time.",sCaptorID);
        return;
    }
    if (llVecDist(llList2Vector(llGetObjectDetails(sCaptorID,[OBJECT_POS] ),0),llGetPos()) > 10 ) {
        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"You could capture %WEARERNAME% if you get a bit closer.",sCaptorID);
        return;
    }
    if (!iIsConfirmed) {
        Dialog(g_kWearer, "\nsecondlife:///app/agent/"+sCaptorID+"/about wants to capture you...", ["Allow","Reject"], ["BACK"], 0, CMD_WEARER, "AllowCaptureMenu", sCaptorID);
    } else {
        llMessageLinked(LINK_SET, CMD_OWNER, "beckon", sCaptorID);
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"You are at "+NameURI(sCaptorID)+"'s whim.",g_kWearer);
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"\n\n%WEARERNAME% is at your mercy.\n\nNOTE: During capture RP %WEARERNAME% cannot refuse your teleport offers and you will keep full control. Type \"/%CHANNEL% %PREFIX% grab\" to attach a leash or \"/%CHANNEL% %PREFIX% capture release\" to relinquish capture access to %WEARERNAME%'s %DEVICETYPE%.\n\nHave fun! For basic instructions click [http://www.opencollar.at/congratulations.html here].\n", sCaptorID);
        g_sTempOwnerID = sCaptorID;
        saveTempOwners();
        llSetTimerEvent(0.0);
    }
}

UserCommand(integer iNum, string sStr, key kID, integer remenu) {
    string sStrLower=llToLower(sStr);
    if (llSubStringIndex(sStr,"capture TempOwner") == 0){
        string sCaptorID = llGetSubString(sStr,llSubStringIndex(sStr,"~")+1,-1);
        if (iNum==CMD_OWNER || iNum==CMD_TRUSTED || iNum==CMD_GROUP) { }
        else Dialog(kID, "\nYou can try to capture %WEARERNAME%.\n\nReady for that?", ["Yes","No"], [], 0, iNum, "ConfirmCaptureMenu", sCaptorID);
    }
    else if (sStrLower == "capture" || sStrLower == "menu capture") {
        if  (iNum!=CMD_OWNER && iNum != CMD_WEARER) {
            if (g_iCaptureOn) Dialog(kID, "\nYou can try to capture %WEARERNAME%.\n\nReady for that?", ["Yes","No"], [], 0, iNum, "ConfirmCaptureMenu", kID);
            else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",kID);
        } else CaptureMenu(kID, iNum);
    }
    else if (iNum!=CMD_OWNER && iNum != CMD_WEARER) { }
    else if (llSubStringIndex(sStrLower,"capture")==0) {
        if (g_sTempOwnerID != "" && kID==g_kWearer) {
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%NOACCESS%",g_kWearer);
            return;
        } else if (sStrLower == "capture on") {
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Capture Mode activated",kID);
            if (g_iRiskyOn && g_iCaptureInfo) {
                llMessageLinked(LINK_DIALOG,SAY,"1"+"%WEARERNAME%: You can capture me if you touch my %DEVICETYPE%...","");
                llSetTimerEvent(900.0);
            }
            g_iCaptureOn=TRUE;
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE,g_sSettingToken+"capture=1", "");
        } else if (sStrLower == "capture off") {
            if(g_iCaptureOn) llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Capture Mode deactivated",kID);
            g_iCaptureOn=FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,g_sSettingToken+"capture", "");
            g_sTempOwnerID = "";
            saveTempOwners();
            llSetTimerEvent(0.0);
        } else if (sStrLower == "capture release") {
            llMessageLinked(LINK_SET, CMD_OWNER, "unleash", kID);
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+NameURI(kID)+" has released you.",g_kWearer);
            llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"You have released %WEARERNAME%.",kID);
            g_sTempOwnerID = "";
            saveTempOwners();
            llSetTimerEvent(0.0);
            return;
        } else if (sStrLower == "capture risky on") {
            llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sSettingToken+"risky=1", "");
            g_iRiskyOn = TRUE;
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Capturing won't require %WEARERNAME%'s consent. \"/%CHANNEL% %PREFIX% capture info off\" will deactivate \"capture me\" announcements.",kID);
            if (g_iCaptureOn && g_iCaptureInfo){
                 llSetTimerEvent(900.0);
                 llMessageLinked(LINK_DIALOG,SAY,"1"+"%WEARERNAME%: You can capture me if you touch my %DEVICETYPE%...","");
                }
        } else if (sStrLower == "capture risky off") {
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, g_sSettingToken+"risky", "");
            g_iRiskyOn = FALSE;
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"Capturing will require %WEARERNAME%'s consent first.",kID);
            llSetTimerEvent(0.0);
        } else if (sStrLower == "capture info on") {
            g_iCaptureInfo = TRUE;
            llMessageLinked(LINK_DIALOG,NOTIFY, "1"+"\"Capture me\" announcements during risky mode are now enabled.", kID);
            llMessageLinked(LINK_SAVE,LM_SETTING_DELETE,g_sSettingToken+"info","");
            if (g_iRiskyOn && g_iCaptureOn) {
                llSetTimerEvent(900.0);
                llMessageLinked(LINK_DIALOG,SAY,"1"+"%WEARERNAME%: You can capture me if you touch my %DEVICETYPE%...","");
            }
        } else if (sStrLower == "capture info off") {
            g_iCaptureInfo = FALSE;
            if (g_iRiskyOn && g_iCaptureOn) llSetTimerEvent(0.0);
            llMessageLinked(LINK_DIALOG,NOTIFY,"1"+"\"Capture me\" announcements during risky mode are now disabled.", kID);
            llMessageLinked(LINK_SAVE,LM_SETTING_SAVE,g_sSettingToken+"info=0","");
        }
        if (remenu) CaptureMenu(kID, iNum);
    }
}

default{
    state_entry() {
        g_kWearer = llGetOwner();
    }

    on_rez(integer iParam) {
        if (llGetOwner()!=g_kWearer)  llResetScript();
    }

    touch_start(integer num_detected) {
        key kToucher = llDetectedKey(0);
        if (kToucher == g_kWearer) return;
        if (g_sTempOwnerID == kToucher) return;
        if (g_sTempOwnerID) return;
        if (!g_iCaptureOn) return;
        if (llVecDist(llDetectedPos(0),llGetPos()) > 10 ) llMessageLinked(LINK_SET,NOTIFY,"0"+"You could capture %WEARERNAME% if you get a bit closer.",kToucher);
        else llMessageLinked(LINK_AUTH,CMD_ZERO,"capture TempOwner~"+(string)kToucher,kToucher);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == "Main") llMessageLinked(iSender, MENUNAME_RESPONSE, "Main|Capture", "");
        else if (iNum == CMD_SAFEWORD || (sStr == "runaway" && iNum == CMD_OWNER)) {
            if (iNum == CMD_SAFEWORD && g_iCaptureOn) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Capture Mode deactivated.", g_kWearer);
            if (llGetAgentSize(g_sTempOwnerID)!=ZERO_VECTOR) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Your capture role play with %WEARERNAME% is over.",g_sTempOwnerID);
            g_iCaptureOn=FALSE;
            g_iRiskyOn = FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,g_sSettingToken+"capture", "");
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,g_sSettingToken+"risky", "");
            g_sTempOwnerID = "";
            saveTempOwners();
            llSetTimerEvent(0.0);
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sSettingToken+"capture") g_iCaptureOn = (integer)sValue;
            else if (sToken == g_sSettingToken+"risky") g_iRiskyOn = (integer)sValue;
            else if (sToken == "auth_tempowner") g_sTempOwnerID = sValue;
            else if (sToken == g_sSettingToken+"info") g_iCaptureInfo = (integer)sValue;
        } else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID, FALSE);
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex+1);
                key kCaptor=llList2Key(g_lMenuIDs, iMenuIndex + 2);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +2);
                if (sMenu=="CaptureMenu") {
                    if (sMessage == "BACK") llMessageLinked(LINK_ROOT, iAuth, "menu Main", kAv);
                    else if (sMessage == "☑ risky") UserCommand(iAuth,"capture risky off",kAv,TRUE);
                    else if (sMessage == "☐ risky") UserCommand(iAuth,"capture risky on",kAv,TRUE);
                    else UserCommand(iAuth,"capture "+sMessage,kAv,TRUE);
                } else if (sMenu=="AllowCaptureMenu") {
                    if (sMessage == "BACK") UserCommand(iNum, "menu capture", kID, FALSE);
                    else if (sMessage == "Allow") doCapture(kCaptor, TRUE);
                    else if (sMessage == "Reject") {
                        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+NameURI(kCaptor)+" didn't pass your face control. Sucks for them!",kAv);
                        llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"Looks like %WEARERNAME% didn't want to be captured after all. C'est la vie!",kCaptor);
                    }
                } else if (sMenu=="ConfirmCaptureMenu") {
                    if (sMessage == "BACK") UserCommand(iNum, "menu capture", kID, FALSE);
                    else if (g_iCaptureOn) {
                        if (sMessage == "Yes") doCapture(kCaptor, g_iRiskyOn);
                        else if (sMessage == "No") llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"You let %WEARERNAME% be.",kAv);
                    } else llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%WEARERNAME% can no longer be captured",kAv);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +2);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_AUTH") LINK_AUTH = iSender;
            else if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == BUILD_REQUEST)
            llMessageLinked(iSender,iNum+g_iBuild,llGetScriptName(),"");
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    timer() {
        if(g_iCaptureInfo) llMessageLinked(LINK_DIALOG,SAY,"1"+"%WEARERNAME%: You can capture me if you touch my %DEVICETYPE%...","");
    }

    changed(integer iChange) {
        if (iChange & CHANGED_TELEPORT) {
            if (g_sTempOwnerID == "") {
                if (g_iRiskyOn && g_iCaptureOn && g_iCaptureInfo) {
                    llMessageLinked(LINK_DIALOG,SAY,"1"+"%WEARERNAME%: You can capture me if you touch my %DEVICETYPE%...","");
                    llSetTimerEvent(900.0);
                }
            }
        }
    }
}
