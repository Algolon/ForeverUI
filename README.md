# Forever UI · v1.3.7

Een rustige, bewerkbare UI voor WoW Forever (interface 16001), met extra's voor feral druids.

## Over deze client: secret values

WoW Forever geeft addons voor health, power, auras en casts vaak **geheime waarden** ("secret values").
Een addon mag die waarden wel tonen, bijvoorbeeld in een balk of als tekst.
Maar een addon mag er niet mee rekenen of vergelijken. Forever UI is daarop aangepast:

- **Shifts:** getoond als 6 blokjes in plaats van een getal. Elk vol blokje is één shift die je mana nog betaalt.
- **Combo points:** blokjes, die de balk zelf vult.
- **Energy-tick:** geschat op basis van timing, niet van de waarde.
- **Swing timer:** uitgeschakeld, want deze client geeft addons geen combat log.
- **Procs:** worden opgezocht op spell-ID.
- **Debuffs van jou op je target:** herkend via het PLAYER-filter.

Krijg je een melding *"geweigerd door de client"*? Typ dan `/fui diag` en stuur de uitkomst door.

## Installeren

1. Kopieer de hele map `ForeverUI` naar de map `Interface\AddOns` in je WoW Forever-installatie.
   De mapnaam moet precies `ForeverUI` blijven.
2. Start het spel. Klik in character select op **AddOns** en controleer of Forever UI aan staat.
3. Zet Lua-foutmeldingen aan, zodat je fouten kunt doorgeven. Typ in je chat:
   `/console scriptErrors 1`

Na het inloggen zie je in je chat: *Forever UI: geladen*.

## Wat zit erin

| Onderdeel | Wat het doet |
|---|---|
| Actiebalk 1 | Wisselt van pagina per form: Caster 1, Cat 7, Prowl 8, Bear 9. Links staat welke pagina actief is. |
| Actiebalk 2 | Blijft altijd hetzelfde. Gebruikt de slots van Blizzards *Bottom Left Action Bar*. |
| Actiebalk 3 | Staat standaard aan (uit met `/fui bar3 uit`). Gebruikt de *Bottom Right Action Bar*. |
| Utility-balk | 12 knoppen rechts op het scherm. Verschijnt als je er met de muis overheen gaat. Gebruikt de *Right Action Bar*. |
| Formbalk | Je forms. **Shift-klik** op een form doet een powershift: uit form en direct terug. Ernaast staat hoeveel shifts je mana nog toelaat. |
| Microbalk & tassen | Blizzards eigen knoppen, rechtsonder, met vrije plekken per tas en in totaal. |
| Speler- en targetframe | Mana blijft zichtbaar in form, met een energy-tick en combo points. Het target toont level-kleur, elite en target-of-target. |
| Cast / swing | Castbar met latency-zone (rood). De swing timer werkt alleen op clients zonder secret values. Een Maul in de wachtrij zie je aan de oplichtende Maul-knop. |
| Buffs & debuffs | Procs en korte buffs (bijv. Clearcasting, Tiger's Fury), debuffs op jou met een genees-hint, en debuffs op je target (die van jou groot, met een gouden rand). |
| XP-balk | Met rested XP. Beweeg de muis erover voor details. |

Je keybinds blijven die van Blizzard. Je stelt ze in via **Esc → Key Bindings**:
- Balk 1 = *Action Button 1–12*
- Balk 2 = *Bottom Left Action Button*
- Utility = *Right Action Button 1–12*
- Formbalk = *Special Action Button* (stance)

Als Clearcasting actief is, lichten Shred, Ravage, Maul en Swipe op.

## Nieuw in v1.3.7

- **Targetframe:** spelers met een achternaam staan er met hun volledige naam, net als op je spelerframe.

## Nieuw in v1.3.6

- **Damage meter:** het class-icoon, een 24x24-frame in een rij van 17 px, wordt een vierkant op de hoogte van de rij.

## Nieuw in v1.3.5

- **Damage meter:**
  - De sessietimer is even klein als de titel.
  - Het class-icoon wordt vierkant op zijn eigen hoogte; ook een icoon zonder herkenbare naam wordt gevonden.

## Nieuw in v1.3.4

- **Damage meter:** de achtergrond en scheidingslijn van de bovenbalk krimpen mee, als ze herkenbare namen hebben. `/fui meter` toont nu ook waar de lijst en de textures aan vastzitten.

## Nieuw in v1.3.3

- **Damage meter:**
  - De bovenbalk is lager: de lijst schuift omhoog met wat de balk aan hoogte verliest.
  - De titel is iets groter dan in 1.3.2.
  - Alleen het sessievenster krijgt nog een rand, dus niet meer twee over elkaar.
  - De lijst zelf wordt niet meer verkleind.

## Nieuw in v1.3.2

- **Damage meter:** de bovenbalk wordt nu ook gevonden als hij dieper in het venster zit. Dropdown, titel en knoppen worden 2/3 zo groot.

## Nieuw in v1.3.1

- **Chatknoppen:** de kolom staat dichter tegen de chat en valt niet meer over de linkerrand van het scherm.

## Nieuw in v1.3

- **Damage meter:**
  - Het class-icoon is een vierkantje op de hoogte van de balk.
  - De tekstgrootte stel je in met `/fui meterfont 9` (8 t/m 16), zodat er meer van de naam past. `/fui meterfont off` zet Blizzards grootte terug.
- **Spelerframe:** je volledige naam, inclusief achternaam.
- **Chat:** de knoppen (social, kanalen, spraak, menu) staan in één kolom linksboven naast de chat.
- **Form bar:** de shift-teller ernaast is weg; die staat al op je spelerframe als je geshift bent.

## Nieuw in v1.2.2

- **Combo-punten:**
  - De rij onder het targetframe verschijnt alleen als je target combo-punten heeft. Target-of-target en de target cast bar schuiven dan mee omlaag.
  - Tijdens een gevecht kan de client het aantal geheimhouden; dan staat de rij er zolang je in cat form bent.
- **Minimap:** de blauwe gloed van het questgebied is terug. Forever UI zette die per ongeluk uit.

## Nieuw in v1.2.1

- **Fix:** Lua-fout in de quest-tooltip, onder andere bij powershiften. Deze client heeft geen globale `GetItemInfo`, dus de addon gebruikt nu `C_Item`.

## Nieuw in v1.2

- **Combo-punten op het targetframe:** een rij onder de powerbalk; op het spelerframe staan ze niet meer. Het targetframe is voor rogue en druid iets hoger, zodat target-of-target en de cast bar vanzelf mee omlaag schuiven.
- **Quest-voortgang in Gilded-stijl:**
  - Meldingen als "Lunar Fungus 9/12" verschijnen in een klein paneel, met de questnaam en een voortgangsbalkje.
  - Andere meldingen blijven op Blizzards plek.
  - Verplaatsen via "Quest Progress" in `/fui`. Uitzetten met `/fui questtoast off` en daarna `/reload`.
- **Slimme tooltip:** bij items staat voor welke quest je ze nog nodig hebt (bijvoorbeeld "Quest: Gathering the Cure (8/12)"), of "Quest item". Uitzetten met `/fui questtip off`.
- **Buff-herinnering:** klikken cast nu via een macro, net als de form bar.
- **Verkopen en repareren** zitten nu in Blizzards eigen UI, dus Forever UI doet het niet meer. Dat loste ook een Lua-fout bij de vendor op.

## Nieuw in v1.1

- **v1.1.1:**
  - Klikken op de buff-herinnering cast nu echt.
  - Muisklikken volgen weer de instelling "cast on key down", omdat de client dat verwacht. Shift+klik op een actieknop doet niets, zodat Shift+slepen een spell verplaatst zonder te casten.
- **Hover-fade:**
  - Chat en damage meter zijn half doorzichtig tot je eroverheen gaat of typt.
  - De sterkte stel je per contextmodus in (in combat, questen, dungeon, raid, PvP, rust) via `/fui fade`. Aan/uit met `/fui fade on|off`.
- **Contextmodus met de hand kiezen:**
  - Rechtsklik op de infobalk of gebruik `/fui mode quest|dungeon|raid|pvp|rest`. Een sterretje (*) betekent dat je hem zelf hebt gekozen.
  - Terug naar automatisch met `/fui mode auto`, of klik door tot na "Resting".
- **Damage meter:** de bovenbalk (dropdown, titel, knoppen) is kleiner, op 2/3 van de grootte.
- **Issue Reporter:** standaard klein en vaag tot je eroverheen gaat. Met `/fui issue hidden` is hij weg, `/fui issue normal` zet hem terug. F6 blijft werken.
- **Chat:** de invoerbalk van elk chatvenster heeft nu de Forever UI-stijl, ook die van later geopende fluistervensters.
- **Buff-herinnering:**
  - Omen of Clarity is eruit; op deze client is het een passief talent, geen buff om te casten. Passieve spells worden nooit meer gevraagd.
  - Voor druid geldt nu: Mark of the Wild en Thorns.

## Nieuw in v1.0: fase 3

- **Actiebalken:**
  - Lege slots zijn onzichtbaar. Ze verschijnen zodra je een spell of item oppakt, en in `/fui`. Altijd tonen: `/fui empty on`.
  - Muisklikken werken nu bij loslaten, zoals bij Blizzard. Shift+slepen verplaatst dus een spell zonder hem te casten. Toetsen volgen nog steeds "cast on key down".
- **Contextmodi:**
  - De infobalk toont je modus: Questing, Dungeon, Raid, PvP of Resting.
  - De quest tracker dimt in combat. In dungeons en raids blijft hij vaag tot je eroverheen gaat. Uit met `/fui context off`.
- **Buff-herinnering:** buiten combat verschijnt een pulserend icoon als een eigen lange buff ontbreekt of bijna afloopt. Voor druid zijn dat Mark of the Wild en Omen of Clarity. Klik op het icoon om de buff te casten. Verplaatsen via "Buff Reminder" in `/fui`; uitzetten met `/fui reminder off`.
- **Sessierapport:** het tooltip van de infobalk toont goud, XP, quests, kills en deaths, ook per uur, plus de geschatte tijd tot je volgende level. Ook via `/fui session`; opnieuw beginnen met `/fui session reset`.
- **Damage meter:** Blizzards damage meter krijgt een warm donker paneel en een bronzen rand; verder blijft hij van Blizzard. `/fui meter` toont welke vensters zijn gevonden.
- **Tassen:** "x free" is weg en de getallen op de tassen zijn groter.

## Nieuw in v0.10: groep en afwerking

- **Partyframes, formaat:** selecteer "Party" in `/fui`. Onder het paneel verschijnen schuifjes voor breedte en hoogte. "Reset frame" zet ook het formaat terug.
- **Rol-icoon** (tank, healer, damage) voor de naam, als de client rollen kent.
- **Ready check:** vinkje, kruisje of vraagteken midden op elk partyframe. Het blijft na afloop nog 6 seconden staan.
- **AFK/DND** naast de naam.
- **Threat, alleen in een groep:**
  - Een gekleurde gloed (geel → rood) om je spelerframe en om partyframes met aggro.
  - Op het targetframe staat je eigen threat, bijvoorbeeld "Threat 72%", links in de powerbalk.

- **Je buffs en debuffs** worden niet meer door Forever UI verplaatst. Ze sprongen terug na een reload, teleport of het openen van Blizzards Edit Mode. Plaats ze voortaan alleen via Blizzards HUD Edit Mode ("Buffs and Debuffs"). Daarom staan ze niet meer in `/fui`.

- **Minimap:** eigen, grotere afronding met een bronzen rand; de kaart volgt precies die bocht, dus geen losse pixels meer in de hoeken. Nieuwe textures: WoW helemaal herstarten (een /reload is niet genoeg).

## Nieuw in v0.9.5

- **Utility-balk** (verticaal, rechts) staat standaard uit. Aanzetten: `/fui util on` en `/reload`. Hij gebruikt de slots van Blizzards *Right Action Bar* (25-36).

## Nieuw in v0.9.4

- **Heal-voorspelling** op speler-, target- en partyframes: inkomende heals verschijnen als lichter groen stuk direct na je health. Je eigen heals zijn feller dan die van andere healers; schilden zijn lichtblauw. Speler en target tonen er ook "+getal" naast.

## Nieuw in v0.9.3

- **Target-iconen:** in 0.9.2 vond Forever UI Blizzards iconen niet, dus bleven ze onder het frame staan. Nu zoekt de addon ze op meerdere manieren en zet ze ook een frame later nog eens goed, voor het geval Blizzard ze na de update opnieuw plaatst. `/fui target info` toont wat er gevonden is ("re-stack: ...").
- **Bewerkmodus, Align to:** selecteer een frame, klik "Align to..." en klik een tweede frame (wordt groen). Met Top, Middle, Bottom, Left, Centre en Right lijn je het geselecteerde frame daarop uit.
- **Energy-tickbalk:** loopt niet meer door bij volle energy. De balk rust leeg tot je energy uitgeeft en de volgende tick binnenkomt.

## Nieuw in v0.9.2

- **Target-iconen:** debuffs staan direct boven je targetframe, buffs daarboven. Rijen van 8 stapelen van onder naar boven, zonder lege ruimte. Blizzard tekent de iconen; Forever UI zet ze na elke update op hun plek.
  Het blok "Target Auras" in `/fui` is daardoor overbodig en weg: de iconen verhuizen mee met je targetframe.
- **Fix:** een frame selecteren in `/fui` gaf een Lua-fout, waardoor je niets kon aanpassen.

## Nieuw in v0.9.1

- **Target-iconen zichtbaar:** Blizzards iconen zitten in TargetFrameContentContextual.Auras. Dat blok bleef per ongeluk verborgen; nu worden alleen de iconen ernaast (leider, PvP, raid) verborgen. De iconen staan standaard boven het Forever UI-targetframe.
- **Bewerkmodus:**
  - Frames lijnen magnetisch uit op andere frames, op de boven- en onderkant en het midden, horizontaal en verticaal. Zo staan het speler- en het targetframe precies even hoog.
  - Het paneel toont de x- en y-positie van het geselecteerde frame.
- **Fix:** `/fui target info` gaf een Lua-fout.

## Nieuw in v0.9: auras die ook in combat werken

**Wat de diagnose liet zien:** deze client weigert addons in combat élke aura. Dat geldt voor je eigen buffs en debuffs én voor die van je target ("40 refused"). Alleen Blizzards eigen frames mogen ze dan tonen.

**Daarom tekent Blizzard nu de auras, en bepaalt Forever UI waar ze staan:**
- **Je buffs:** Blizzards buff-rij, rechtsboven naast de minimap.
- **Je debuffs:** Blizzards debuff-rij, net boven je spelerframe.
- **Buffs en debuffs van je target:** de iconen van Blizzards targetframe, onder je Forever UI-targetframe. Nu worden alleen de art, balken en teksten van dat frame verborgen, de iconen niet meer.
- **Verplaatsen:** alle drie in `/fui`, via "Buffs (Blizzard)", "Debuffs (Blizzard)" en "Target Auras".
- **Eigen rijen:** de Forever UI-rijen (procs, buffs, debuffs) staan uit, want in combat blijven ze leeg. Terugzetten kan met `/fui playerauras forever` en `/fui targetauras forever`.
- **Procs:** voor procs zoals Clearcasting, Enrage of Tiger's Fury heeft Blizzard de **Cooldown Manager** ("Tracked Buffs"). Die werkt wel in combat en kun je boven je spelerframe zetten.
- **Diagnose:** `/fui target info` laat zien waar Blizzards target-iconen staan, handig als ze niet verschijnen.

## Nieuw in v0.8.5

- **Target-buffs en -debuffs in combat:** komen van Blizzards eigen targetframe. Dat is het enige frame dat de client ze in combat laat lezen.
  - Het frame draait onzichtbaar; alleen de iconen zijn te zien.
  - De iconen komen vanzelf onder het Forever UI-targetframe te staan. Verschuiven kan in `/fui` via "Target Auras".
- **Procs in combat:** als de client de gegevens van een buff geheim houdt, weet de addon nog wat hij er buiten combat van wist. Een nieuwe buff die je zelf cast (Enrage, Tiger's Fury, een HoT) komt in de procs-rij.
- **Diagnose:** `/fui diag` toont onder "auras during last combat" wat de client in het laatste gevecht wel en niet doorgaf.

## Nieuw in v0.8.4

- **Kanaalnamen in de chat:** standaard kort. "[1. General - Redridge Mountains]" wordt "[1]".
  - Kies met `/fui chat short` voor [1], met `/fui chat name` voor [1. General], of met `/fui chat off` voor Blizzards tekst.
  - De naam blijft klikbaar.
- **Target-buffs en -debuffs:** standaard weer van Forever UI zelf. Deze keuze wordt onthouden.
- **Questtracker:** de rand eromheen is weg; hij ziet er weer uit zoals Blizzards eigen tracker.

## Nieuw in v0.8.3

- **Spelerframe:** "zzz" als je in een rustgebied bent (herberg of stad), gekruiste zwaarden in combat.
- **Iconen op de frames (speler, target, party):** raid-markeringen zoals een schedel of ster, een kroontje voor de groepsleider, en een PvP-vlag op je spelerframe.
- **Wapen-enchants:** sharpening stones, oils en poisons staan links van de buff-rij, met hun resterende tijd.
- **Reputatie:** een dunne balk onder de XP-balk voor de factie die je volgt. Beweeg de muis erover voor details.
- **Infobalk:** klik erop voor Blizzards stopwatch en wekker. Die zaten eerst op de minimapklok.
- **Buffs:** de buff-rij laat alleen nog weg wat de procs-rij echt toont. Zo kan geen enkele buff meer tussen de twee rijen verdwijnen.
  `/fui auras` laat nu per buff de duur en de rij zien, en hoe de procs-rij hem vond.

## Nieuw in v0.8.2

- **Chat kopiëren:** klik op het notitie-icoontje rechtsboven in de chat, of typ `/fui copy`.
  - Er opent een venster met de laatste 300 regels van het actieve tabblad, zonder link- en kleurcodes.
  - Alles is al geselecteerd: Ctrl+C kopieert meteen alles. Je kunt ook zelf een stuk selecteren.
  - Regels die de client geheim houdt, worden overgeslagen en onderaan geteld.
- **Questtracker:** de achtergrond groeit mee met wat er echt staat. Is de tracker ingeklapt, dan omlijnt hij alleen nog de kop.

## Nieuw in v0.8.1

- **Afgeronde hoeken op elke client:** de addon bouwt ze nu zelf op uit kleine hoekstukjes. De minimap heeft ook ronde hoeken.
- **Target-buffs en -debuffs (ook in combat):** Blizzards targetframe blijft onzichtbaar actief. Alleen zijn buff- en debuff-iconen blijven zichtbaar.
  Zet ze boven het Forever UI-targetframe via HUD Edit Mode → "Target and Focus" (zet daar ook "Buffs on Top" aan).
  Liever de eigen Forever UI-iconen? Gebruik `/fui targetauras forever`; die tonen in combat niets.
- **Chat:** Blizzards eigen chatachtergrond is weg. De Forever UI-achtergrond, tabbladen en het invoerveld zijn in dezelfde stijl.
- **Questtracker:** heeft een Forever UI-achtergrond met bronzen rand.
- **Infobalk:** een echte balk in vakjes, met gedempte labels, witte waarden en kleur bij waarschuwingen.

## Nieuw in v0.8

- **Stijl "Gilded Monolith"**, egaal over de hele UI:
  - donkere panelen met een bronzen rand, een lichte binnenlijn en licht ronde hoeken;
  - iconen met ronde hoeken en balken met een subtiele glans;
  - namen in Friz, cijfers in Arial Narrow.
- **Zelfde stijl voor Blizzard-onderdelen:** de tassen en de chat (achtergrond en invoerveld) hebben dezelfde rand. De minimap heeft ronde hoeken.
  Tip: zet de achtergrond van Blizzards chatvenster op 0% (rechtsklik op het chat-tabblad → Settings), dan zie je alleen de Forever UI-achtergrond.
- **Reagent bag** staat nu in de tassenbalk.
- **Procs-rij:** je eigen Rejuvenation, Regrowth, Nature's Grasp en Enrage verschijnen boven het spelerframe. Er zijn nu drie zoekmethodes: op spell-ID, op naam en door de lijst te doorlopen.
- **Nieuwe commando's:**
  - `/fui auras` toont per buff of de addon hem kan lezen en in welke rij hij staat.
  - `/fui target info` toont uit welke onderdelen Blizzards targetframe bestaat. Dat is nodig voor het onderzoek naar target-debuffs in combat.

## Nieuw in v0.7

- **Party frames:** links op het scherm, in de stijl van het spelerframe. Blizzards party frames zijn verborgen.
  - Een gekleurde rand betekent dat het partylid een debuff heeft die jíj kunt verwijderen. Groen is Poison, paars is Curse.
  - Je eigen Rejuvenation en Regrowth staan als kleine iconen rechtsboven.
  - Een partylid buiten bereik wordt gedimd.
  - Klik om te targeten, rechtsklik voor het menu, en beweeg de muis erover voor de tooltip.
- De questtracker blijft van Blizzard (keuze A).

## Nieuw in v0.6

- **Buffs:** een eigen rij rechtsboven, naast de minimap. Blizzards buff-rij is verborgen.
  - Procs en forms staan er niet in; die hebben hun eigen plek.
  - Rechtsklik annuleert een buff, maar alleen buiten combat. Zo kan de addon nooit per ongeluk de verkeerde buff annuleren.
- **Minimap:** vierkant en randloos, met zone en coördinaten eronder. Scroll om in en uit te zoomen.
  - Blizzards knopjes (tracking, mail, kalender, queue) staan in een rij onder de kaart. Die rij wordt fel als je de muis over de minimap beweegt.
- **Infobalk:** linksboven, met tijd, fps, ms, goud, tassen en durability. Beweeg de muis erover voor details.
- Debuffs die de client geheim houdt worden overgeslagen, in plaats van dat ze de hele rij laten verdwijnen.

## Nieuw in v0.5

- Het Forever UI-targetframe staat standaard aan.
- Onder het targetframe staat links de castbar van je target en rechts een klein target-of-target-frame. Samen zijn ze even breed als het targetframe.
- Target-buffs staan in een rij boven de target-debuffs. Buffs die je kunt stelen of purgen hebben een blauwe rand.
- Op het spelerframe verschijnen gekruiste zwaarden zolang je in combat bent.
- Swing timer: gebruik Blizzards eigen "Swing Timer" (HUD Edit Mode → Combat). Een addon kan op deze client geen swings volgen.

## Nieuw in v0.4

- De teksten in het spel zijn Engels.
- Balk 3 (rechts) en balk 4 (links) staan als 2×6-raster naast de hoofdbalken. Balk 4 gebruikt de *Left Action Bar*.
  Zet ze uit met `/fui bar3 off` of `/fui bar4 off`.
- Het label van de form links van balk 1 is weg.
- Cooldowns gebruiken de methode die met secret values werkt. Ze blijven zichtbaar na een shift, en worden alleen ververst als de game een wijziging meldt. Dat voorkomt het flikkeren.
- Het targetframe is standaard weer dat van Blizzard. Alleen dat frame mag in combat de buffs en debuffs van je target lezen. Target of target en de tooltip krijg je er zo ook bij. Verplaatsen doe je in Blizzards HUD Edit Mode.
  Met `/fui target forever` kies je het eigen frame, maar dat heeft in combat geen target-auras.
- Spelerframe: beweeg de muis erover voor de gewone tooltip.

## Bewerken

- `/fui` zet de bewerkmodus aan en uit. Dit kan alleen buiten combat.
- Klik op een blauw vlak om dat frame te selecteren.
- Sleep het frame, of verschuif het met de pijltjestoetsen (met Shift erbij: 10 px per stap).
- Met de schuifjes stel je schaal en dekking in.
- **Zichtbaar** wisselt tussen:
  - Altijd
  - Mouseover
  - Ademen: gedimd als er niets gebeurt
- **Esc** of **Klaar** sluit de bewerkmodus. Wijzigingen worden direct opgeslagen.

## Commando's

- `/fui diag` toont een technische diagnose: welke Blizzard-frames er zijn, welke modules draaien en wat er geweigerd werd.
- `/fui profile` toont je profielen.
- `/fui profile Bear` wisselt naar het profiel "Bear". Bestaat het nog niet, dan wordt het een kopie van je huidige profiel.
- `/fui bar3 on|off` zet de derde actiebalk aan of uit. Daarna is `/reload` nodig.
- `/fui keydown auto|on|off` bepaalt of knoppen afgaan bij toets-in of toets-los (zie hieronder).
- `/fui reset confirm` zet de hele layout van je profiel terug naar de standaard.

## Testlijst

Nog niet getest op WoW Forever. Loop deze lijst door en meld wat niet klopt:

1. Verschijnt *Forever UI: geladen* in je chat zonder foutmelding?
2. Staan je spells op balk 1 en balk 2, en werken de toetsen?
3. **Belangrijk:** druk op je Prowl-toets. Gaat Prowl aan en blijft hij aan?
   Gaat hij aan en direct weer uit, of gebeurt er niets? Probeer dan `/fui keydown uit` of `/fui keydown aan`.
4. Wisselt balk 1 van pagina in Cat, Prowl en Bear? Staat de juiste naam links van de balk?
5. Werkt Shift-klik op Cat Form in Cat als powershift? Krijg je de energy van Furor?
6. Loopt de energy-tick onder je energy-balk, en kloppen de combo points?
7. Werken de microknoppen en tassen, en klopt het aantal vrije plekken?
8. Kun je in `/fui` frames verplaatsen, en staan ze na `/reload` nog op dezelfde plek?
9. Opent rechtsklik op je spelerframe het menu?

## Bekende beperkingen (v0.1)

- **Lange buffs** staan nog in Blizzards eigen buff-rij rechtsboven. Daar kun je buffs annuleren met rechtsklik.
  Debuffs op jou zie je daardoor ook twee keer. Een eigen versie volgt in fase 2.
- **Verborgen Blizzard-onderdelen:** de standaard hoofdbalk wordt verborgen. Daarmee verdwijnen ook de pet bar en de reputatiebalk.
- **Bottom Right Action Bar:** verdwijnt ook als je `/fui bar3` niet aanzet.
- **Blizzards HUD Edit Mode:** kan Forever UI-frames niet verplaatsen. Gebruik daarvoor `/fui`.
- **Nog niet gebouwd (fase 2):** party frames, questtracker, minimap, infobalk en contextmodi.
