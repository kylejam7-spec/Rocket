-- Client entry: starts every controller, then opens the shared state subscription.
-- Controllers live in Controllers/, UI components in UI/.
local Players = game:GetService("Players")
local Controllers = script.Parent:WaitForChild("Controllers")
local State = require(Controllers:WaitForChild("State"))
-- Wait here so no controller yields inside UI.Create.screen and two of them
-- build the same ScreenGui.
Players.LocalPlayer:WaitForChild("PlayerGui")

for _, name in { "CameraController", "LaunchEffectsController", "HudController", "ProgressController",
    "GymSignController", "TrainingController", "GymAnimationController", "CargoController", "PromptController", "DeliveryFeedbackController",
    "ActionController", "SettingsController", "TutorialController", "UpgradesController", "DestinationController", "WheelController",
    "PetController", "UfoShopController", "PetsController" } do
    task.spawn(require(Controllers:WaitForChild(name)).start)
end
State.start()
