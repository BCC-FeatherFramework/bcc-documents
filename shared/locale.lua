Locales = {} --Credit to bcc-boats for this

-- Translate string; a key missing from the configured language falls back to English.
function _(str, ...)
	local language = Locales[Config.defaultlang] or Locales['en_lang']
	local text = language and language[str] or (Locales['en_lang'] and Locales['en_lang'][str])
	if text == nil then
		return 'Translation [' .. tostring(Config.defaultlang) .. '][' .. str .. '] does not exist'
	end
	return string.format(text, ...)
end

function _U(str, ...) -- Translate string first char uppercase
	return tostring(_(str, ...):gsub("^%l", string.upper))
end
