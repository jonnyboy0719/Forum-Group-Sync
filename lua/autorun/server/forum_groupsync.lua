-- SMF Group Sync by Godz
-- Modified by JonnyBoy0719

--Config
local DB_HOST = ""
local DB_USERNAME = ""
local DB_PASSWORD = ""
local DB_FORUM_DATABASE = ""
local DB_PORT = 3306

--Currently only supports SMF, phpBB and MyBB
local Forum_Mod = "phpbb"

--Should it sync according to SMF/MyBB/phpBB's groups?
local FORUM_to_ULX = false

--Should it sync according to ULX groups?
local ULX_to_FORUM = true

--"SteamID" or "IP". If you have "IP" enabled, you don't have
--to have Steam logins setup but this method is dangerous
--if someone has the same IP of someone you are syncing.
--Keep "SteamID" if possible.
local Sync_Method = "SteamID"

--This will read the current forum table.
--Example:
--phpbb_
--mybb_
--smf_
local Forum_Table = "phpbb_auto_"

--Your ULX group must equal your Forum's group's ID.
--Every line except the last one should be followed
--by a comma. See Facepunch/Coderhire post for details.
GroupID={
    ["user"]=0, --0 is the default SMF group; 2 is the default MyBB group and phpBB
    ["moderator"]=4,
    ["superadmin"]=13
}

--==========================================--
--               END OF CONFIG			
--==========================================--



function log (msg)
	ServerLog("[Forum Group Sync] "..msg.."\n")
end

require ("mysqloo")

local db = mysqloo.connect(DB_HOST, DB_USERNAME, DB_PASSWORD, DB_FORUM_DATABASE, DB_PORT)

function QueryDB(query, callback)
    q = db:query(query)
    
    function q:onSuccess(result)
        if callback then
            callback(result)
        end
    end
    
    function q:onError(err, sql)
        log("Query errored.")
        log("Query: ", sql)
        log("Error: ", err)
		
        if db:status() == 2 then
			db:connect()
			
			function db:onConnected()
				q:start()
			end
			
		end
    end
    q:start()
end

function db:onConnectionFailed(err)
    log("Database connection failed.")
    log("Error: ", err)
end

function db:onConnected()
    log("Connection to Forum MySQL (v"..db:serverVersion()..") database successful.")
end

function splitPort(ip)
	local pos = string.find(ip, ":")
	local str = string.sub(ip, 1, pos - 1)
	
	return str
end

function FlipTable(table, NewTable)
	local NewTable = {}
	
	for k, v in next, table do
		local key = k
		local value = tostring(v)

		table.v = k
	end

	return NewTable
end


function playerJoin(pl)
	if not pl:IsValid() then return end

	local steamID = pl:SteamID64()
	local low_mod = string.lower(Forum_Mod)
	local low_method = string.lower(Sync_Method)
	local forumtable = string.lower(Forum_Table)
	local getID = GroupID[pl:GetUserGroup()]
	local IP = splitPort(pl:IPAddress())

	if low_mod == "smf" and low_method == "steamid" then
		querycheck = "SELECT * FROM "..forumtable.."members WHERE member_name="..steamID..";"
		queryB = "UPDATE "..forumtable.."members SET id_group="..getID.." WHERE member_ip='"..IP.."';"
		log("Synced SMF User: "..steamID.." to Forum with GroupID: "..getID)
	elseif low_mod == "mybb" and low_method == "steamid" then
		querycheck = "SELECT * FROM "..forumtable.."users WHERE loginname='"..steamID.."';"
		queryB = "UPDATE "..forumtable.."users SET usergroup="..getID.." WHERE loginname='"..steamID.."';"
		log("Synced MyBB User: "..steamID.." to Forum with GroupID: "..getID)
	elseif low_mod == "phpbb" and low_method == "steamid" then
		querycheck = "SELECT * FROM "..forumtable.."users WHERE user_steam='"..steamID.."';"
		queryB = "UPDATE "..forumtable.."users SET group_id="..getID.." WHERE user_steam='"..steamID.."';"
		log("Synced phpBB User: "..steamID.." to Forum with GroupID: "..getID)
	elseif low_mod != "smf"  then
		timer.Simple(10, function() log("Error: \""..Forum_Mod.."\" is not a valid forum mod.") end)
	elseif low_method == "" or nil then
		timer.Simple(10, function() log("Please choose a sync method.") end)
	else
		timer.Simple(10, function() log("Something went wrong, please contact Godz.") end)
	end	


	QueryDB(querycheck, function(data)
		
		if ULX_to_FORUM then
			if data[1]["id_group"] != getID then

				-- made an empty function because I don't know if you can have an empty arg like this
				QueryDB(queryB, function() end)	
				-- if its phpBB, or any other forum software that has a group table, then we need to call this
				if low_mod == "phpbb" and data[1]["user_steam"] != nil then

					local getUser = data[1]["user_id"]
					queryA = "INSERT IGNORE INTO "..forumtable.."user_group (group_id, user_id, group_leader, user_pending) VALUES ('"..getID.."', '"..getUser.."', 0, 0);"

					QueryDB(queryA, function() end)	
				end

			elseif not data then
				log("It appears that you do not have Steam logins set up. Please change your sync method or set up Steam logins.")
			end
		end

		if FORUM_to_ULX then
			FlipTable(GroupID, ReversedGroupID)

			ULib.ucl.addUser(pl:SteamID(), {}, {}, ReversedGroupID[data[1]["id_group"]])
		end
	end)
end
hook.Add("PlayerInitialSpawn", "queryOnGroupChange", playerJoin) -- Only gets called when the player joins
--hook.Add("UCLChanged", "queryOnChange", playerJoin) -- Only gets called if the user has been added to a new group

concommand.Add("sync_status", function()
	log(db:status())
end)

db:connect()
