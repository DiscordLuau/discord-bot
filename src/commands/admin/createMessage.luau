local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local permissionGuard = require("../../utilities/permissionGuard")
local respondCommand = require("../../utilities/respondCommand")

local builders = require("../../../luau_packages/builders")

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

return {
	command = COMMAND_OBJECT,
	category = "Admin",
	cooldown = { { seconds = 5, per = "user" } },
	guards = { permissionGuard({ "admin" }) },

	execute = function(interaction)
		local options = interaction.data.options
		local channelId: string = options[1].value
		local messageContent: string = options[2].value
		local channelResult = discordBot:getChannelAsync(channelId):await()

		if channelResult:isErr() then
			local errorMessage = channelResult:unwrapErr()

			logger:warn(`/create-message failed to fetch channel {channelId}: {errorMessage}`)

			interaction:messageAsync(respondCommand(`Failed to fetch channel: {errorMessage}`, true)):poll()

			return
		end

		local sentResult = channelResult
			:unwrapOk()
			:createMessageAsync(builders.message.message.new():setContent(messageContent):build())
			:await()

		if sentResult:isErr() then
			local errorMessage = sentResult:unwrapErr()

			logger:warn(`/create-message failed to send to channel {channelId}: {errorMessage}`)

			interaction:messageAsync(respondCommand(`Failed to send message: {errorMessage}`, true)):poll()

			return
		end

		local sentMessage = sentResult:unwrapOk()

		logger:info(`/create-message sent message {sentMessage.id} to channel {channelId}`)

		interaction:messageAsync(respondCommand(`Message sent. ID: \`{sentMessage.id}\``)):poll()
	end,
}
