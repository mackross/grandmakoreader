-- Library filing order for book titles, after the ALA Filing Rules (1980).
-- KOReader runs only the numbered files in this folder. Patches load this one with dofile.
--
-- A leading "The", "A", or "An" is ignored. Titles file word by word, so a shorter word comes before a
-- longer one that begins the same way. Numbers come before letters, in order of their value. Hyphens,
-- dashes, slashes, full stops, and underscores separate words. Other punctuation, capitals, and accents
-- make no difference.
local Utf8Proc = require("ffi/utf8proc")

local Library = {}

local articles = { the = true, a = true, an = true }

-- Accented letters file as their plain letter. Each plain letter is followed by its accented forms.
local plain_letters = {}
for plain, accented in ("a:àáâãäåāăą c:çćč d:ďđð e:èéêëēėęě g:ğ i:ìíîïīįı l:ł n:ñńň o:òóôõöøōő r:ř s:śşš "
        .. "t:ťţ u:ùúûüūůűų y:ýÿ z:źżž ae:æ oe:œ ss:ß th:þ"):gmatch("(%a+):(%S+)") do
    for letter in accented:gmatch("[\194-\244][\128-\191]*") do
        plain_letters[letter] = plain
    end
end

local word_separators = { ["-"] = true, ["/"] = true, ["."] = true, ["_"] = true, ["–"] = true, ["—"] = true }
local ignored_marks = { ["‘"] = true, ["’"] = true, ["“"] = true, ["”"] = true, ["…"] = true }

-- The words of a title in lower case, with plain letters and no punctuation.
local function plainWords(title)
    local words, word = {}, {}
    local function endWord()
        if #word > 0 then
            words[#words + 1] = table.concat(word)
            word = {}
        end
    end
    for character in Utf8Proc.lowercase(title):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if character:match("^%s$") or word_separators[character] then
            endWord()
        elseif character:match("^%w$") then
            word[#word + 1] = character
        elseif #character > 1 and not ignored_marks[character] then
            word[#word + 1] = plain_letters[character] or character
        end
    end
    endWord()
    return words
end

-- The words a title files under: its plain words without a leading article.
local function filingWords(title)
    local words = plainWords(title)
    if #words > 1 and articles[words[1]] then
        table.remove(words, 1)
    end
    return words
end

-- A string that sorts in filing order under plain comparison. A space sorts before every digit and
-- letter, and a number carries its length first so that 9 sorts before 10.
local function filingKey(title)
    local words = filingWords(title)
    for index, word in ipairs(words) do
        local number = word:match("^0*(%d+)$")
        if number then
            words[index] = string.format("%03d%s", #number, number)
        end
    end
    return table.concat(words, " ")
end

--- Sorts a list into library order, in place.
-- @param items the list to sort
-- @param titleOf returns an item's title; omit it for a list of titles
function Library.sort(items, titleOf)
    local keys = {}
    for _, item in ipairs(items) do
        local title = titleOf and titleOf(item) or item
        keys[item] = { filingKey(title), title }
    end
    table.sort(items, function(first, second)
        local first_key, second_key = keys[first], keys[second]
        if first_key[1] ~= second_key[1] then
            return first_key[1] < second_key[1]
        end
        return first_key[2] < second_key[2]
    end)
    return items
end

--- The letter or digit a title is filed under, such as "S" for "The Secret Garden".
function Library.initial(title)
    local word = filingWords(title)[1] or title
    return Utf8Proc.uppercase_dumb(word:match("[%z\1-\127\194-\244][\128-\191]*") or "")
end

-- A filed title as characters, such as { "s", "e", "c", ... } for "The Secret Garden".
local function filedCharacters(title)
    local characters = {}
    for character in table.concat(filingWords(title), " "):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        characters[#characters + 1] = character
    end
    return characters
end

-- The first count characters, with each word capitalised, such as "Sec" for "The Secret Garden".
local function beginning(characters, count)
    local shown = {}
    for index = 1, math.min(count, #characters) do
        local character = characters[index]
        shown[index] = (index == 1 or characters[index - 1] == " ") and Utf8Proc.uppercase_dumb(character)
            or character
    end
    return (table.concat(shown):gsub("%s+$", ""))
end

--- The first characters of a filed title, such as "Sil" for "Silas Marner" and a count of 3.
function Library.prefix(title, count)
    return beginning(filedCharacters(title), count)
end

--- The shortest beginnings that tell two neighbouring titles apart, like the letters on an
-- encyclopedia's spines, such as "Sec" and "Sen" for "The Secret Garden" and "Sense and Sensibility".
-- Neither runs past longest characters, so titles that agree that far get the same beginning.
function Library.beginnings(before, after, longest)
    local before_characters, after_characters = filedCharacters(before), filedCharacters(after)
    local count = 1
    while count < longest and after_characters[count] and before_characters[count] == after_characters[count] do
        count = count + 1
    end
    -- A space alone tells nothing apart on a label, so the later title shows its next letter too.
    local after_count = after_characters[count] == " " and math.min(count + 1, longest) or count
    return beginning(before_characters, count), beginning(after_characters, after_count)
end

--- Whether a title contains the given words, whatever their capitals, accents, or punctuation.
function Library.contains(title, text)
    local wanted = table.concat(plainWords(text), " ")
    return wanted ~= "" and table.concat(plainWords(title), " "):find(wanted, 1, true) ~= nil
end

return Library
