local TempoRange = {}

---@param noteChart ncdk.NoteChart
function TempoRange:find(noteChart, minTime, maxTime)
	local lastTime = minTime
	local durations = {}

	for _, layerData in noteChart:getLayerDataIterator() do
		for tempoDataIndex = 1, layerData:getTempoDataCount() do
			local tempoData = layerData:getTempoData(tempoDataIndex)
			local nextTempoData = layerData:getTempoData(tempoDataIndex + 1)

			local startTime = lastTime
			local endTime
			if not nextTempoData then
				endTime = maxTime
			else
				endTime = math.min(maxTime, nextTempoData.timePoint.absoluteTime)
			end
			lastTime = endTime

			local tempo = tempoData.tempo
			durations[tempo] = (durations[tempo] or 0) + endTime - startTime
		end
	end

	local longestDuration = 0
	local average, minimum, maximum = 1, 1, 1

	for tempo, duration in pairs(durations) do
		if duration > longestDuration then
			longestDuration = duration
			average = tempo
		end
		if not minimum or tempo < minimum then
			minimum = tempo
		end
		if not maximum or tempo > maximum then
			maximum = tempo
		end
	end

	return average, minimum, maximum
end

return TempoRange
