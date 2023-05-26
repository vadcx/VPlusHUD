
function VHUDPlus:isStealthMode()
	return managers.groupai and managers.groupai:state():whisper_mode()
end

function VHUDPlus:getPagersAnsweredCount()
	if not self:isStealthMode() then
		log("VHUDPlus: getPagersAnsweredCount called outside of stealth mode!")
	end
	-- That's how the official code counts it and there's no API
	local pagersAnswered = managers.groupai:state():get_nr_successful_alarm_pager_bluffs()
	return pagersAnswered
end

function VHUDPlus:getPagersAnswerableMaxCount()
	if not self:isStealthMode() then
		log("VHUDPlus: getPagersAnswerableMaxCount called outside of stealth mode!")
	end

	local pagersData
	if managers.player:has_category_upgrade("player", "corpse_alarm_pager_bluff") then
		pagersData = tweak_data.player.alarm_pager.bluff_success_chance_w_skill
	else
		pagersData = tweak_data.player.alarm_pager.bluff_success_chance
	end

	local answerableMax = #pagersData

	for i = 0, #pagersData do
		local chance = pagersData[i]
		if chance == 0 then
			answerableMax = i - 1

			break
		end
	end

	return answerableMax
end
