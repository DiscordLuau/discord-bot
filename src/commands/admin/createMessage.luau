local builders = require("../../../luau_packages/builders")

local commands = require("../../singletons/commands")
local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("create-message")
	:setDescription("Send a message to a channel")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:setDefaultMemberPermissions(8)
	:addOption(
		builders.interaction.option
			.new()
			:setType("Channel")
			:setName("channel")
			:setDescription("The channel to send the message to")
			:setRequired(true)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("String")
			:setName("content")
			:setDescription("The message content")
			:setRequired(true)
			:setMaxLength(2000)
			:build()
	)
	:build()

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "create-message" then
			return
		end

		handleInteraction(interaction, { "admin" }, function()
			local options = interaction.data.options

			local channelId: string = options[1].value
			local messageContent: string = options[2].value

			local channelResult = discordBot:getChannelAsync(channelId):await()

			if channelResult:isErr() then
				local errorMessage = channelResult:unwrapErr()

				logger:warn(`/create-message failed to fetch channel {channelId}: {errorMessage}`)

				interaction:messageAsync(respondCommand(`Failed to fetch channel: {errorMessage}`)):poll()

				return
			end

			local sentResult = channelResult:unwrapOk()
				:createMessageAsync(
					builders.message.message
						.new()
						:setContent(messageContent)
						:build()
				)
				:await()

			if sentResult:isErr() then
				local errorMessage = sentResult:unwrapErr()

				logger:warn(`/create-message failed to send to channel {channelId}: {errorMessage}`)

				interaction:messageAsync(respondCommand(`Failed to send message: {errorMessage}`)):poll()

				return
			end

			local sentMessage = sentResult:unwrapOk()

			logger:info(`/create-message sent message {sentMessage.id} to channel {channelId}`)

			interaction:messageAsync(respondCommand(`Message sent. ID: \`{sentMessage.id}\``)):poll()
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
