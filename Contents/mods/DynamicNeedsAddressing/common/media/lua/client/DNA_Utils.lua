DNA = DNA or {}

DNA.DEBUG = true   

function DNA.debug(msg)
    if not DNA.DEBUG then return end
    print(msg)
end