local function write_log(msg)
	local path = vim.fn.getcwd() .. "/probe-rs.log"
	local file = io.open(path, "a")
	if file then
		file:write(msg .. "\n")
		file:close()
	end
end

return {
	setup = function(dap)
		dap.listeners.before["event_probe-rs-rtt-channel-config"]["probe-rs"] = function(session, body)
			local msg =
				string.format("%s: Open RTT channel %d (%s)", os.date("%F %T"), body.channelNumber, body.channelName)
			vim.notify(msg)
			write_log(msg)
			session:request("rttWindowOpened", { body.channelNumber, true })
		end

		dap.listeners.before["event_probe-rs-rtt-data"]["probe-rs"] = function(_, body)
			local msg = string.format("%s: RTT[%d] %s", os.date("%F %T"), body.channelNumber, body.data)
			require("dap.repl").append(msg)
			write_log(msg)
		end

		dap.listeners.before["event_probe-rs-show-message"]["probe-rs"] = function(_, body)
			local msg = string.format("%s: Message: %s", os.date("%F %T"), body.message)
			require("dap.repl").append(msg)
			write_log(msg)
		end
	end,
}
