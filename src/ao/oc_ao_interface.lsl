
//  Copyright (c) 2008 - 2016 Nandana Singh, Jessenia Mocha, Alexei Maven,
//  Wendy Starfall, littlemousy, Garvin Twine, Romka Swallowtail et al.
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
//

// Debug(string sStr) { llOwnerSay("Debug ["+llGetScriptName()+"]: " + sStr); }

integer g_iInterfaceChannel = -12587429;
integer g_iObjectchannel = -1812221819;//only send on this channel, not listen
integer g_iListenHandle;
integer CMD_ZERO = 0;
integer CMD_AUTH = 42;
integer CMD_TO_COLLAR = 498; // -- Added to send commands TO the collar.
integer CMD_COLLAR = 499;
integer CMD_OWNER = 500;
integer g_iCollarIntegration;
key g_kWearer;
string g_sSeparator = "|";
integer g_iCounter;
key g_kCollarID;
string g_sPendingCmd;

integer g_iUpdateChannel = -7483220;

init() {
//we dont know what was changed in the collar so lets starts fresh with our cache
    g_kCollarID = NULL_KEY;
    g_iCollarIntegration = FALSE; // -- 3.381 to avoid double message on login
    llRegionSayTo(g_kWearer, g_iInterfaceChannel, "OpenCollar?");
    g_iCounter = 0;
    llSetTimerEvent(30.0);
}

StartUpdate(key kID) {
    integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
    llSetRemoteScriptAccessPin(pin);
    llRegionSayTo(kID, -7483220, "ready|" + (string)pin );
}

default
{
    changed(integer iChange) {
        if(iChange & CHANGED_INVENTORY) {
            llResetScript();
        }
    }
    
    state_entry() {
        g_kWearer = llGetOwner();
        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        g_iListenHandle = llListen(g_iInterfaceChannel, "", "", "");
        g_iObjectchannel = -llAbs((integer)("0x"+llGetSubString((string)llGetOwner(),-7,-1)));
        init();
    }
    
    on_rez(integer start) {
        if( g_kWearer != llGetOwner()) llResetScript();
        init();
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == CMD_TO_COLLAR) {
            llRegionSayTo(g_kWearer,g_iObjectchannel, sStr);
        } else if (iNum == CMD_ZERO) {
            if (g_iCollarIntegration) {
                llRegionSayTo(g_kWearer,g_iInterfaceChannel,"AuthRequest|"+(string)kID);
                g_sPendingCmd =  sStr;
            } else 
                llMessageLinked(LINK_THIS, CMD_OWNER, sStr, kID);
        } else if (iNum == CMD_AUTH && sStr == "ZHAO_RESET") {
            llSleep(2); // -- Don't reset immediately, ensure the Interface is ready for us
            llResetScript();
        }
    }
    
    listen(integer iChannel, string sName, key kID, string sMessage) {
        //Debug("Listen: " + sMessage);        
        if (sMessage == "OpenCollar=No" && kID == g_kCollarID) { //Collar said it got detached
            g_iCollarIntegration = FALSE;
            g_kCollarID = NULL_KEY;
            //llListenRemove(g_iListenHandle);
            //g_iListenHandle = llListen(g_iInterfaceChannel, "", "", "");
           // llMessageLinked(LINK_THIS, COLLAR_INT_REQ, "CollarOff", "");
            return;
        }        
        //do nothing if wearer isnt owner of the object
        if (llGetOwnerKey(kID) != g_kWearer) return;
        //Collar announces itself
        if (sMessage == "OpenCollar=Yes") {
            g_iCollarIntegration = TRUE;
            g_kCollarID = kID;
           // llListenRemove(g_iListenHandle);
           // g_iListenHandle = llListen(g_iInterfaceChannel, "", g_kCollarID, "");
            //llMessageLinked(LINK_THIS, COLLAR_INT, sMessage, "");
           // llMessageLinked(LINK_THIS, COLLAR_INT_REQ, "CollarOn", "");
            return;
        } else if (llUnescapeURL(sMessage) == "SAFEWORD") {
            llMessageLinked(LINK_THIS, CMD_COLLAR, "safeword", "");
            //llSay(0,llUnescapeURL(sMessage));
            return;
        } else if (sMessage == "-.. --- / .- ---") {
            StartUpdate(kID);
            return;
        }
        //CollarCommand|iAuth|Command|UUID
        //AuthReply|UUID|iAuth
        list lParams = llParseString2List(sMessage,["|"],[]);
        string sMessageType = llList2String(lParams,0);
        integer iAuth;
        //Debug(sMessageType);
        if (sMessageType == "AuthReply") {
            iAuth = llList2Integer(lParams,2);
            if (g_sPendingCmd) {
                llMessageLinked(LINK_THIS, iAuth, g_sPendingCmd, llList2Key(lParams,1));
                g_sPendingCmd = "";
            }
        } else if (sMessageType == "CollarCommand") {
            iAuth = llList2Integer(lParams,1);
            if (iAuth)
                llMessageLinked(LINK_THIS, iAuth, llList2String(lParams,2), llList2Key(lParams,3));
        }
    }
    
    timer() {
        if (g_kCollarID != NULL_KEY) {
            if (llKey2Name(g_kCollarID) == "") { //the collar is somehow gone...
            //check 2 times again if the collar is really gone, then switch to CollarRequest mode
                if (g_iCounter <= 2) {
                    g_iCounter++;
                    llSetTimerEvent(10.0);
                } else if (g_iCollarIntegration) {
                    g_iCollarIntegration = FALSE;
                    llSetTimerEvent(20.0);
                //    g_kCollarID = NULL_KEY;
                 //   llListenRemove(g_iListenHandle);
                  //  g_iListenHandle = llListen(g_iInterfaceChannel, "", "", "");
                    g_iCounter = 0;
                    llRegionSayTo(g_kWearer, g_iInterfaceChannel, "OpenCollar?");
                   // llMessageLinked(LINK_THIS, COLLAR_INT_REQ, "CollarOff", "");
                }
            }
        } else { // Else, we need to ensure the rest of the hud knows the collar is missing and needs to be refound.
            if (g_iCollarIntegration) {// -- The collar is gone but we think it's still here
                g_iCollarIntegration = FALSE;
                llSetTimerEvent(20.0);
                g_kCollarID = NULL_KEY;
                // llListenRemove(g_iListenHandle);
                //  g_iListenHandle = llListen(g_iInterfaceChannel, "", "", "");
                llRegionSayTo(g_kWearer, g_iInterfaceChannel, "OpenCollar?");
                // llMessageLinked(LINK_THIS, COLLAR_INT_REQ, "CollarOff", "");
            } else  // -- We need to continue to ask if the collar is there
                llRegionSayTo(g_kWearer, g_iInterfaceChannel, "OpenCollar?");
        }
    }
}
