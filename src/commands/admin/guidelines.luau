local builders = require("../../../luau_packages/builders")

local config = require("../../config")
local database = require("../../singletons/database")
local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local guidelines = require("../../utilities/guidelines")
local permissionGuard = require("../../utilities/permissionGuard")
local respondCommand = require("../../utilities/respondCommand")

local IS_COMPONENTS_V2 = 32768

local function touchLastUpdated()
	database:setConfig("guidelines_last_updated", tostring(os.time()))
end

local function buildGuidelinesContainer(guidelinesList: { guidelines.Guideline })
	local lines = {}
	local displayNumber = 1

	for _, guideline in guidelinesList do
		if guideline.hidden == 0 then
			table.insert(lines, `**{displayNumber}.** {guideline.text}`)

			displayNumber += 1
		end
	end

	if displayNumber == 1 then
		table.insert(lines, "*No guidelines have been set yet.*")
	end

	local consequences = database:getConfig("guidelines_consequences")
	local lastUpdatedRaw = database:getConfig("guidelines_last_updated")
	local lastUpdated = tonumber(lastUpdatedRaw) or 0

	local footerParts = {}

	if consequences ~= "" then
		table.insert(footerParts, `-# **Consequences:** {consequences}`)
	end

	if lastUpdated ~= 0 then
		local formatted = os.date("!%B %d, %Y at %H:%M UTC", lastUpdated)

		table.insert(footerParts, `-# Last updated: {formatted}`)
	end

	local container = builders.message.components.container
		.new()
		:addComponent(builders.message.components.textDisplay.new():setContent("## Server Guidelines"):build())
		:addComponent(builders.message.components.separator.new():setDivider(true):setSpacing(1):build())
		:addComponent(builders.message.components.textDisplay.new():setContent(table.concat(lines, "\n")):build())

	if #footerParts > 0 then
		container:addComponent(builders.message.components.separator.new():setDivider(false):setSpacing(1):build())
		container:addComponent(
			builders.message.components.textDisplay.new():setContent(table.concat(footerParts, "\n")):build()
		)
	end

	return container:build()
end

local function formatGuidelinesList(guidelinesList: { guidelines.Guideline }): string
	if #guidelinesList == 0 then
		return "No guidelines exist yet."
	end

	local lines = { "**All Guidelines**", "" }

	for _, guideline in guidelinesList do
		local status = if guideline.hidden == 1 then "[hidden]" else "[visible]"

		table.insert(lines, `ID {guideline.id}  {status}  {guideline.text}`)
	end

	local consequences = database:getConfig("guidelines_consequences")

	if consequences ~= "" then
		table.insert(lines, "")
		table.insert(lines, `**Consequences:** {consequences}`)
	end

	return table.concat(lines, "\n")
end

local function updateGuidelinesMessage(guidelinesList: { guidelines.Guideline }): (boolean, string?)
	local channelResult = discordBot:getChannelAsync(config.guidelinesChannelId):await()

	if channelResult:isErr() then
		local errorMessage = channelResult:unwrapErr()

		logger:warn(`Failed to fetch guidelines channel: {errorMessage}`)

		return false, `Failed to fetch guidelines channel: {errorMessage}`
	end

	local messageResult = channelResult:unwrapOk():getMessageAsync(config.guidelinesMessageId):await()

	if messageResult:isErr() then
		local errorMessage = messageResult:unwrapErr()

		logger:warn(`Failed to fetch guidelines message: {errorMessage}`)

		return false, `Failed to fetch guidelines message: {errorMessage}`
	end

	local editPayload = builders.message.editMessage
		.new()
		:setFlags(IS_COMPONENTS_V2)
		:addComponent(buildGuidelinesContainer(guidelinesList))
		:build()

	editPayload.content = zune.serde.json.values.null

	local editResult = messageResult:unwrapOk():editAsync(editPayload):await()

	if editResult:isErr() then
		local errorMessage = editResult:unwrapErr()

		logger:warn(`Failed to edit guidelines message: {errorMessage}`)

		return false, `Failed to edit guidelines message: {errorMessage}`
	end

	return true, nil
end

local idOption = builders.interaction.option
	.new()
	:setType("Integer")
	:setName("id")
	:setDescription("The ID of the guideline (use /manage-guidelines list to see IDs)")
	:setRequired(true)
	:setMinValue(1)
	:build()

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("manage-guidelines")
	:setDescription("Manage server guidelines")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:setDefaultMemberPermissions(8)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("add")
			:setDescription("Add a new guideline")
			:addOption(
				builders.interaction.option
					.new()
					:setType("String")
					:setName("text")
					:setDescription("The guideline text")
					:setRequired(true)
					:build()
			)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("remove")
			:setDescription("Permanently remove a guideline")
			:addOption(idOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("hide")
			:setDescription("Hide a guideline from the guidelines message without deleting it")
			:addOption(idOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("unhide")
			:setDescription("Make a hidden guideline visible again")
			:addOption(idOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("list")
			:setDescription("List all guidelines including hidden ones")
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("update")
			:setDescription("Push the current guidelines to the guidelines message")
			:build()
	)
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Admin",
	cooldown = { { seconds = 5, per = "user" } },
	guards = { permissionGuard({ "admin" }) },

	execute = function() end,

	subcommands = {
		add = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]
				local textOption = subcommand.options and subcommand.options[1]

				if not textOption or not textOption.value or textOption.value == "" then
					interaction:messageAsync(respondCommand("No guideline text provided.", true)):poll()

					return
				end

				local guidelineText: string = textOption.value
				local newId = guidelines.create(guidelineText)

				touchLastUpdated()

				local guidelinesList = guidelines.getAll()
				local updateSuccess, updateError = updateGuidelinesMessage(guidelinesList)

				if not updateSuccess then
					interaction
						:messageAsync(
							respondCommand(
								`Guideline added (ID {newId}) but failed to update the guidelines message: {updateError}`,
								true
							)
						)
						:poll()

					return
				end

				interaction:messageAsync(respondCommand(`Added guideline ID {newId}: "{guidelineText}"`)):poll()
			end,
		},
		remove = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]
				local guidelineIdOption = subcommand.options and subcommand.options[1]
				local guidelineId: number = guidelineIdOption and guidelineIdOption.value
				local existing = guidelines.get(guidelineId)

				if not existing then
					logger:warn(`remove: no guideline found with ID {guidelineId}`)

					interaction:messageAsync(respondCommand(`No guideline found with ID {guidelineId}.`, true)):poll()

					return
				end

				guidelines.delete(guidelineId)

				touchLastUpdated()

				local guidelinesList = guidelines.getAll()
				local updateSuccess, updateError = updateGuidelinesMessage(guidelinesList)

				if not updateSuccess then
					interaction
						:messageAsync(
							respondCommand(
								`Guideline removed but failed to update the guidelines message: {updateError}`,
								true
							)
						)
						:poll()

					return
				end

				interaction:messageAsync(respondCommand(`Removed guideline ID {guidelineId}: "{existing.text}"`)):poll()
			end,
		},
		hide = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]
				local guidelineIdOption = subcommand.options and subcommand.options[1]
				local guidelineId: number = guidelineIdOption and guidelineIdOption.value
				local existing = guidelines.get(guidelineId)

				if not existing then
					logger:warn(`hide: no guideline found with ID {guidelineId}`)

					interaction:messageAsync(respondCommand(`No guideline found with ID {guidelineId}.`, true)):poll()

					return
				end

				if existing.hidden == 1 then
					interaction
						:messageAsync(respondCommand(`Guideline ID {guidelineId} is already hidden.`, true))
						:poll()

					return
				end

				guidelines.setHidden(guidelineId, true)

				touchLastUpdated()

				local guidelinesList = guidelines.getAll()
				local updateSuccess, updateError = updateGuidelinesMessage(guidelinesList)

				if not updateSuccess then
					interaction
						:messageAsync(
							respondCommand(
								`Guideline hidden but failed to update the guidelines message: {updateError}`,
								true
							)
						)
						:poll()

					return
				end

				interaction:messageAsync(respondCommand(`Hidden guideline ID {guidelineId}: "{existing.text}"`)):poll()
			end,
		},
		unhide = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]
				local guidelineIdOption = subcommand.options and subcommand.options[1]
				local guidelineId: number = guidelineIdOption and guidelineIdOption.value
				local existing = guidelines.get(guidelineId)

				if not existing then
					logger:warn(`unhide: no guideline found with ID {guidelineId}`)

					interaction:messageAsync(respondCommand(`No guideline found with ID {guidelineId}.`, true)):poll()

					return
				end

				if existing.hidden == 0 then
					interaction
						:messageAsync(respondCommand(`Guideline ID {guidelineId} is already visible.`, true))
						:poll()

					return
				end

				guidelines.setHidden(guidelineId, false)

				touchLastUpdated()

				local guidelinesList = guidelines.getAll()
				local updateSuccess, updateError = updateGuidelinesMessage(guidelinesList)

				if not updateSuccess then
					interaction
						:messageAsync(
							respondCommand(
								`Guideline unhidden but failed to update the guidelines message: {updateError}`,
								true
							)
						)
						:poll()

					return
				end

				interaction
					:messageAsync(respondCommand(`Unhidden guideline ID {guidelineId}: "{existing.text}"`))
					:poll()
			end,
		},
		list = {
			execute = function(interaction)
				local guidelinesList = guidelines.getAll()

				interaction:messageAsync(respondCommand(formatGuidelinesList(guidelinesList))):poll()
			end,
		},
		update = {
			execute = function(interaction)
				local guidelinesList = guidelines.getAll()
				local updateSuccess, updateError = updateGuidelinesMessage(guidelinesList)

				if not updateSuccess then
					interaction
						:messageAsync(respondCommand(`Failed to update guidelines message: {updateError}`, true))
						:poll()

					return
				end

				interaction
					:messageAsync(respondCommand(`Guidelines message updated with {#guidelinesList} guideline(s).`))
					:poll()
			end,
		},
	},
}
