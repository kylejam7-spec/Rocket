--[[
    Fly everyone to a destination now (Studio playtests only). Two ways:

    1. Studio chat during Play:   /launch blackhole        (or moon, mars, europa, saturn)
                                  /launch blackhole 3 20   (3 s countdown, 20 s stay)
    2. Command bar, with the view switched to Server during Play: paste the line below,
       edited. Works from the Building or Fueling phase: it swaps in that mission,
       finishes the build and the fuel, puts every player in the cabin and launches
       after `countdown` seconds (5 by default). `stay` shortens the reward stay
       (at least 12 s so the wheel still spins; the Black Hole's singularity takes the
       last 4 s).
]]
print(game.ServerScriptService.Main.RocketDebug:Invoke("launch", "BlackHole", { countdown = 3, stay = 20 }))
