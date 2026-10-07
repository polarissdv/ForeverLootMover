local ADDON_NAME, ns = ...

-- =========================================================
-- TRANSLATIONS
-- =========================================================
-- English is the reference: a missing key falls back to it, so a partial
-- translation is fine. Keep the %s / %d placeholders and the |cff...|r colors.
local L = {
    en = {
        -- Anchor
        ANCHOR_TITLE = "Loot roll bars",
        ANCHOR_HINT = "Drag to move",
        ANCHOR_HINT2 = "Wheel: size  ·  Right-click: done",

        -- Options
        SUBTITLE = "The loot roll bars, where you want them",
        SECTION_GENERAL = "GENERAL",
        SECTION_POSITION = "POSITION",
        ENABLED = "Addon enabled",
        ENABLED_DESC = "Off: the bars go back to where the game puts them after a /reload.",
        MINIMAP_BUTTON = "Minimap button",
        MINIMAP_BUTTON_DESC = "Show the round button around the minimap.",
        GROW_UP = "Stack upwards",
        GROW_UP_DESC = "Off: every new roll bar is added below the previous one.",
        CLAMP = "Keep on screen",
        CLAMP_DESC = "Stops the bars from being dragged off the edge of the screen.",
        ALERTS = "Move the loot toast too",
        ALERTS_DESC = "The \"You received\" panel lands on the anchor too, instead of where the game puts it. Off: a /reload gives it its usual spot back.",
        SMOOTH = "Smooth movement",
        SMOOTH_DESC = "The bars fade in, and the stack slides back into place when a roll is over instead of jumping.",
        SCALE = "Bar size",
        SPACING = "Gap between bars",
        PLACE = "Place the bars",
        TEST = "Test with an item",
        TEST_HIDE = "Stop the test",
        HIDE_PLACE = "Done placing",
        RESET_POSITION = "Default position",
        RESET_ALL = "Reset everything",
        CONFIRM = "Click again",
        LANGUAGE = "Language",
        RESET_DONE = "Settings back to default.",

        -- Chat
        WELCOME = "loaded. |cffffd100/flm|r to place the loot roll bars, |cffffd100/flm options|r for the rest.",
        MOVED = "Bars moved. |cffffd100/flm|r to place them again.",
        SCALE_SET = "Bar size: %d%%",
        SCALE_INVALID = "Give a size between 50 and 300, for example |cffffd100/flm scale 120|r.",
        POSITION_RESET = "Position back to default.",
        PLACING = "Drag the grey bar where you want it. Right-click it when you are done.",
        DISABLED = "ForeverLootMover is off. |cffffd100/flm on|r to turn it back on.",
        TURNED_ON = "ForeverLootMover is on.",
        TEST_SHOWN = "Two test rolls, for 30 seconds. They are not real: nothing is rolled on.",
        TEST_UNAVAILABLE = "This build does not hand out its loot roll template, so a test bar cannot be built. Run |cffffd100/flm scan|r while a real roll is on screen and send me the result.",
        MINIMAP_ON = "Minimap button shown. Cannot see it? Another addon such as HidingBar may have collected it into its own bar.",
        MINIMAP_OFF = "Minimap button hidden.",
        TURNED_OFF = "ForeverLootMover is off. The game keeps the bars where they are until a /reload.",
        NOT_FOUND = "No loot roll bar found in this build yet. Run |cffffd100/flm scan|r while a roll is on screen and send me the result.",

        -- Tooltip
        TT_PLACE = "Left-click: place the bars",
        TT_OPTIONS = "Right-click: options",

        HELP = "|cffffd100/flm|r place the bars  |cff806030.|r  |cffffd100/flm test|r  |cff806030.|r  |cffffd100/flm options|r  |cff806030.|r  |cffffd100/flm scale 120|r  |cff806030.|r  |cffffd100/flm reset|r  |cff806030.|r  |cffffd100/flm scan|r",
    },

    fr = {
        -- Ancre
        ANCHOR_TITLE = "Barres de butin",
        ANCHOR_HINT = "Glisse pour déplacer",
        ANCHOR_HINT2 = "Molette : taille  ·  Clic droit : terminé",

        -- Options
        SUBTITLE = "Les barres de jet de butin, là où tu veux",
        SECTION_GENERAL = "GÉNÉRAL",
        SECTION_POSITION = "POSITION",
        ENABLED = "Addon activé",
        ENABLED_DESC = "Désactivé : les barres retournent à leur place d'origine après un /reload.",
        MINIMAP_BUTTON = "Bouton de minicarte",
        MINIMAP_BUTTON_DESC = "Affiche le bouton rond autour de la minicarte.",
        GROW_UP = "Empiler vers le haut",
        GROW_UP_DESC = "Désactivé : chaque nouvelle barre s'ajoute en dessous de la précédente.",
        CLAMP = "Garder à l'écran",
        CLAMP_DESC = "Empêche de faire sortir les barres du bord de l'écran.",
        ALERTS = "Déplacer aussi le butin reçu",
        ALERTS_DESC = "Le panneau \"Vous recevez\" se place aussi sur l'ancre, au lieu de l'endroit choisi par le jeu. Désactivé : un /reload lui rend sa place habituelle.",
        SMOOTH = "Mouvements fluides",
        SMOOTH_DESC = "Les barres apparaissent en fondu, et la pile se remet en place en glissant quand un jet se termine, au lieu de sauter.",
        SCALE = "Taille des barres",
        SPACING = "Écart entre les barres",
        PLACE = "Placer les barres",
        TEST = "Tester avec un objet",
        TEST_HIDE = "Arrêter le test",
        HIDE_PLACE = "Terminer le placement",
        RESET_POSITION = "Position par défaut",
        RESET_ALL = "Tout réinitialiser",
        CONFIRM = "Clique encore",
        LANGUAGE = "Langue",
        RESET_DONE = "Réglages remis par défaut.",

        -- Chat
        WELCOME = "chargé. |cffffd100/flm|r pour placer les barres de butin, |cffffd100/flm options|r pour le reste.",
        MOVED = "Barres déplacées. |cffffd100/flm|r pour les replacer.",
        SCALE_SET = "Taille des barres : %d%%",
        SCALE_INVALID = "Donne une taille entre 50 et 300, par exemple |cffffd100/flm scale 120|r.",
        POSITION_RESET = "Position remise par défaut.",
        PLACING = "Glisse la barre grise où tu veux. Clic droit dessus quand c'est bon.",
        DISABLED = "ForeverLootMover est désactivé. |cffffd100/flm on|r pour le rallumer.",
        TURNED_ON = "ForeverLootMover est activé.",
        TEST_SHOWN = "Deux jets de test, pendant 30 secondes. Ce ne sont pas de vrais jets : rien n'est lancé.",
        TEST_UNAVAILABLE = "Ce build ne donne pas son modèle de barre de butin, impossible de construire une barre de test. Lance |cffffd100/flm scan|r pendant un vrai jet et envoie-moi le résultat.",
        MINIMAP_ON = "Bouton de minicarte affiché. Tu ne le vois pas ? Un autre addon comme HidingBar l'a peut-être rangé dans sa propre barre.",
        MINIMAP_OFF = "Bouton de minicarte masqué.",
        TURNED_OFF = "ForeverLootMover est désactivé. Le jeu garde les barres en place jusqu'au prochain /reload.",
        NOT_FOUND = "Aucune barre de jet trouvée dans cette version. Lance |cffffd100/flm scan|r pendant qu'un jet est affiché et envoie-moi le résultat.",

        -- Infobulle
        TT_PLACE = "Clic gauche : placer les barres",
        TT_OPTIONS = "Clic droit : les options",

        HELP = "|cffffd100/flm|r placer les barres  |cff806030.|r  |cffffd100/flm test|r  |cff806030.|r  |cffffd100/flm options|r  |cff806030.|r  |cffffd100/flm scale 120|r  |cff806030.|r  |cffffd100/flm reset|r  |cff806030.|r  |cffffd100/flm scan|r",
    },
}

ns.LOCALES = { en = "English", fr = "Français" }
ns.LOCALE_ORDER = { "en", "fr" }

-- A missing key falls back to English, a missing language too
local fallback = L.en
ns.L = setmetatable({}, {
    __index = function(_, key)
        local code = ns.db and ns.db.locale
        if not code or code == "auto" then
            code = (GetLocale() or "enUS"):sub(1, 2)
        end
        local tbl = L[code]
        local value = tbl and tbl[key]
        if value ~= nil then return value end
        return fallback[key] or key
    end,
})

-- Called when the language changes. Every label is read through ns.L, so the
-- panels only have to be told to refresh.
function ns.LanguageChanged()
    if ns.RefreshOptions then ns.RefreshOptions() end
    if ns.Anchor then ns.Anchor.Refresh() end
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
end
