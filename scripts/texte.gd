class_name Texte
extends RefCounted
## Längere Texte: Hilfe-Wiki, Hintergrundgeschichte, Lebensgeschichten, Flirtsprüche.

const LEGENDE := "Als die Welt noch in Asche lag, stieg Alderan auf den Glutberg und trug eine Handvoll lebendiger Glut ins Tal. Zwölf steinerne Schalen ließ er errichten, vom Dämmerwald bis zu den Aschenlanden, und zwölf Hüter schworen, sie nie verlöschen zu lassen. Man nannte sie die Glutwacht.\n\nSolange die Schalen brannten, schlief die Asche. Doch Hüter sind Menschen. Sie wurden alt, sie stritten, einige gingen fort. Schale um Schale erlosch, und mit jeder kroch der Aschenschlaf näher: Wer ihm verfällt, vergisst zuerst seinen Namen, dann sein Gesicht. Was bleibt, sind Knochen, die noch marschieren.\n\nHeute brennt im ganzen Land keine einzige Schale mehr. Von der Glutwacht ist nur Hauptmann Gernot geblieben, in einem Dorf, das früher Glutfurt hieß und sich seit dem dritten Verlöschen Aschfurt nennt. Er hat einen letzten Brief geschrieben, an den letzten Namen auf seiner Liste. An dich."

const KLASSEN_GESCHICHTE := {
	"ritter": "Du warst Schildträger in der Garde von Hohenmark, bis die Garde aufgelöst wurde, weil es nichts mehr zu bewachen gab. Dein Großvater trug den Mantel der Glutwacht. Sein Name stand auf Gernots Liste, deiner darunter.",
	"barbar": "Du kommst aus den Frostklüften, wo man sagt: Wer das Feuer nicht hütet, erfriert zu Recht. Als die Schale deines Stammes erlosch, bist du losgezogen, um herauszufinden, wer sie hätte hüten sollen. Die Spur endet in Aschfurt.",
	"magier": "Du hast an der Akademie von Silberhall gelernt, dass die Glut keine Flamme ist, sondern eine Erinnerung der Welt an ihre Wärme. Deine Lehrer hielten das für ein Gleichnis. Du nicht. Gernots Brief war die erste Einladung, es zu beweisen.",
	"schurke": "Du hast in den Gassen von Rabenhafen gelernt, dass man alles stehlen kann, nur keine Zeit. Der Brief der Glutwacht war nicht an dich gerichtet. Du hast ihn einem Toten abgenommen, der ihn nicht mehr brauchte, und beschlossen, sein Versprechen zu halten.",
	"waldlaeufer": "Du bist an den Rändern des Dämmerwaldes aufgewachsen und hast gesehen, wie er Jahr für Jahr stiller wurde. Die Tiere gingen zuerst. Deine Mutter war Fährtenleserin der Glutwacht; ihr Bogen ist jetzt deiner, ihr Eid auch.",
}

const BIO := {
	"gernot": "Ich war der Jüngste der Zwölf, als ich den Eid ablegte. Heute bin ich der Letzte. Ich habe elf Freunde begraben und einen verloren, den ich nicht begraben konnte: Er steht noch in den Ruinen, in seiner Rüstung, und weiß nicht mehr, wer er ist.",
	"hilda": "Mein Vater hat die Glutschmiede gebaut und ist beim dritten Verlöschen in den Wald gegangen, um die Schale neu zu entzünden. Er kam nicht zurück. Ich habe die Esse drei Jahre kalt gelassen, aus Trotz. Dann habe ich gemerkt, dass Trotz kein Eisen formt.",
	"bruno": "Zwanzig Jahre Söldner, drei Kriege, kein einziger, der es wert war. Den Kessel hier habe ich einem toten Feldkoch abgekauft, na ja, geerbt. Seitdem kämpfe ich nur noch gegen Hunger, und den Krieg gewinne ich jeden Abend.",
	"mira": "Ich bin mit einem Karren voller Stoffe nach Aschfurt gekommen und wollte nach zwei Tagen weiter. Dann brach die Achse, dann kam der Winter, dann hatte ich Stammkunden. Die Hauptstadt läuft mir nicht weg. Sage ich mir seit sechs Jahren.",
	"elara": "Die Akademie hat mich hinausgeworfen, weil ich behauptet habe, die Glut könne denken. Hier draußen hört mir wenigstens der Wald zu. Ich schreibe alles auf, was die alten Schalen flüstern. Eines Tages wird jemand froh sein, dass es jemand getan hat.",
	"finn": "Ich bin im Sumpf groß geworden, bevor er so wurde wie jetzt. Mein Bruder ist dort geblieben. Nicht tot, glaube ich. Nur vergessen. Ich jage, weil man im Wald nicht nachdenken muss, und ich bleibe nie lange, weil man im Dorf damit anfängt.",
	"tomas": "Mein Hof ist der dritte an dieser Stelle. Die ersten beiden hat die Asche geholt. Jedes Mal haben wir neu gesät. Die Leute halten mich für stur. Ich halte mich für einen Bauern, das ist dasselbe, nur mit Rüben.",
	"odo": "Früher habe ich im Dämmerwald geschlagen, die besten Stämme weit und breit. Bis einer geblutet hat. Kein Harz, Blut. Seitdem fälle ich nur noch am Dorfrand und frage vorher höflich.",
	"lina": "Ich habe den Teich von meiner Großmutter geerbt, samt den Enten und einem Karpfen, der älter ist als das Dorf. Den fange ich nie. Wir haben eine Abmachung.",
	"karl": "Ich wollte zur Glutwacht, aber die nimmt keinen mehr auf, weil es sie kaum noch gibt. Also bewache ich das Südtor. Der Hauptmann sagt, das sei dasselbe. Ich glaube, er sagt das, damit ich bleibe.",
	"bertha": "Die Mühle mahlt seit vier Generationen, und in jeder gab es eine Bertha. Ich weiß, wer im Dorf wen mag, wer wem Geld schuldet und wer nachts heimlich am Brunnen sitzt. Frag mich ruhig. Ich sage es dir sowieso.",
	"jorik": "Zwölf Jahre unter Tage in der alten Mine. Dann fing das Erz an zu klappern, und es war kein Erz. Ich bin als Letzter raus und habe den Stollen nicht zugemacht. Das werfe ich mir jeden Tag vor.",
	"walda": "Weidenau war ein Fischerdorf mit vierzig Booten. Jetzt sind es drei, und eines davon ist meins. Solange ich hier ausschenke, hat das Dorf einen Grund, abends zusammenzukommen. Mehr braucht ein Dorf nicht.",
	"ivo": "Ich fahre jeden Morgen hinaus, auch wenn der See nichts hergibt. Mein Vater hat gesagt: Ein Fischer, der an Land bleibt, ist nur ein Mann mit nassen Stiefeln.",
	"greta": "Mein Mann ist mit der Flut hinausgefahren und nicht mit ihr zurückgekommen. Den Anker über der Tür hat er selbst geschmiedet. Solange der hängt, bleibt die Kneipe offen.",
	"marek": "Ich habe auf jedem Wasser gesegelt, das einen Namen hat, und auf zweien ohne. Geblieben ist mir die Möwe und ein See, der zu klein ist für uns beide.",
	"nele": "Ich bin die Jüngste von sieben und die Einzige, die rechnen kann. Also stehe ich am Stand, und die anderen sechs fahren hinaus. Wer von uns das bessere Los hat, weiß ich bis heute nicht.",
	"ole": "Mein Vater hat das Feuer gehütet, sein Vater vor ihm. Als die Schmuggler kamen, habe ich die Lampe selbst gelöscht, damit sie mich leben lassen. Das war das Feigste, was ich je getan habe.",
	"bjarne": "Ich habe bei den Zwergen gelernt, sagen sie im Tal. Unsinn. Ich habe bei meiner Mutter gelernt, und die war strenger als jeder Zwerg.",
	"sigrun": "Die Hütte hat mein Großvater gebaut, für Wanderer, die es nicht mehr ins Tal schaffen. Ich habe schon vierzehn Leute aus dem Schnee gegraben. Elf davon lebend.",
	"torvald": "Ich war einmal Soldat. Dann habe ich gemerkt, dass Wölfe ehrlicher jagen als Menschen, und bin hiergeblieben.",
	"ylva": "Meine Schwester und ich haben jeden Gipfel hier bestiegen. Sie wollte immer noch einen höher. Seit sie in die Eishöhle ging, führe ich allein.",
	"konrad": "Ich war der dickste Junge von Dornfeld, und alle haben gelacht. Heute bin ich der dickste Mann, und alle zahlen bei mir.",
	"rosalind": "Ich sollte den Hof erben und Rüben ziehen. Ich habe stattdessen Rosen gepflanzt, quer über das beste Feld. Mein Vater spricht seit vier Jahren nicht mit mir. Die Rosen blühen trotzdem.",
	"hedda": "Drei Missernten, zwei Brände, ein Räuberüberfall. Und trotzdem steht der Hof. Frag nicht, wie. Früh aufstehen, das ist alles.",
	"veit": "Ich fahre die Strecke seit zwanzig Jahren. Früher zehn Fuhren die Woche, heute zwei, wenn die Räuber gnädig sind. Aber ich fahre.",
	"selma": "Ich flechte Körbe, Reusen und alles, was halten soll. Früher für den Markt in Aschfurt, heute für die, die geblieben sind. Geblieben sind die Sturen. Mit denen kann ich gut.",
}

const ITEM_INFO := {
	"brot": "Grundnahrung. Billig, sättigt ordentlich.", "kaese": "Sättigt, Zutat für das Festmahl.", "karotte": "Wächst wild auf Wiesen. Zutat für Eintopf.",
	"kartoffel": "Wächst wild. Zutat für Eintopf.", "zwiebel": "Wächst wild. Zutat für Eintopf.", "tomate": "Wächst wild, kleine Mahlzeit.", "salat": "Wächst wild, kleine Mahlzeit.",
	"fleisch": "Roh gegessen schadet es. Am Herd oder Feuer wird Braten daraus.", "braten": "Sättigt stark und heilt. Zutat für das Festmahl.",
	"eintopf": "Aus Karotte, Kartoffel und Zwiebel. Sättigt sehr gut.", "festmahl": "Aus Braten, Käse und Brot. Macht vollständig satt.",
	"fisch": "Am Teich oder See geangelt. Roh ungesund, gebraten gut.", "bratfisch": "Gebratener Fisch, sättigt gut.",
	"heiltrank": "Stellt 80 Leben wieder her. Schnelltaste R.", "manatrank": "Stellt 60 Mana wieder her.",
	"pfeil": "Munition für den Bogen. Jeder Schuss verbraucht einen, im Krämerladen gibt es Zehnerbündel.",
	"holz": "Am Holzplatz gehackt. Für Pfeile an der Werkbank oder zum Verkaufen.", "ei": "Von den eigenen Hühnern. Zwei ergeben Rührei.", "ruehrei": "Aus zwei Eiern, sättigt gut.",
	"saat_karotte": "Im Garten neben deinem Haus pflanzen, nach zwei Tagen ernten.", "saat_kartoffel": "Für den Garten.", "saat_tomate": "Für den Garten.", "saat_zwiebel": "Für den Garten.",
	"kraut": "Wächst wild. Grundzutat für Elaras Alchemie.", "staerketrank": "+25 % Schaden für drei Minuten.", "gift": "Waffengift: die nächsten 25 Treffer machen 35 % mehr Schaden.",
	"schaufel": "Zum Graben nach Schätzen.", "schatzkarte": "Im Inventar lesen, dann zeigt die Karte ein Kreuz. Dort mit der Schaufel graben.",
	"fackel": "Taste T zündet sie an. Brennt sechs Spielstunden und macht die Nacht hell.",
	"erz": "Für die Schmiede. Gibt es an der alten Mine und manchmal bei Skeletten.", "knochen": "Lassen Skelette fallen. Mira braucht es für Salben, sonst verkaufen.",
	"splitter": "Selten. Für Runen in der Schmiede.", "blume": "Wächst im Dämmerwald. Beliebtes Geschenk, Elara braucht sie für ihre Forschung.",
	"kette": "Teures Geschenk. Mira freut sich besonders.", "buch": "Geschenk für Gelehrte.", "met": "Geschenk, das fast jedem schmeckt.",
	"ring": "Für den Antrag, wenn die Zuneigung groß genug ist.", "lieferung": "Gehört Finn.",
}

const WIKI := [
	["steuerung", "Steuerung", "Laufen: W A S D, mit Umschalt sprinten\nAngriff: linke Maustaste gedrückt halten\nBlocken: rechte Maustaste\nAusweichen: Leertaste (kostet Ausdauer, kurz unverwundbar)\nFähigkeiten: 1, 2, 3\nWaffe wechseln: Q\nFackel: T\nBenutzen und Sprechen: E\nEssen: F (das beste Essen im Gepäck), Heiltrank: R\n\nKamera drehen: mittlere Maustaste gedrückt halten und ziehen, oder Alt und linke Maustaste, oder die Tasten Y und X\nKamera neigen: beim Ziehen hoch und runter\nZoom: Mausrad\n\nInventar: I · Charakter: C · Aufgaben: J · Karte: M · Hilfe: H · Cheats: F1 · Menü: Esc\nSchnellspeichern: F5 · Bildschirmfoto: F12\n\nGamepad: in den Einstellungen einschaltbar (Voreinstellung aus). Läuft die Figur von allein los, ist meist ein angeschlossenes Gamepad, Lenkrad oder ein driftender Stick schuld; dann das Gamepad dort ausgeschaltet lassen."],
	["kampf", "Kampf und Waffen", "Du trägst zwei Waffen in zwei Slots und wechselst mit Q. Welche Waffe in welchem Slot steckt, legst du im Inventar fest.\n\nNahkampfwaffen treffen alles vor dir in Reichweite. Bogen und Zauberstab schießen auf den nächsten Gegner. Jede Waffe nutzt ein Attribut: Schwert, Axt, Hammer, Speer und Zweihänder die Stärke, Dolche und Bogen das Geschick, der Zauberstab die Intelligenz.\n\nJede Klasse ist an bestimmten Waffen geübt. Mit ungeübten Waffen machst du 25 % weniger Schaden.\n\nGezielt wird mit der Maus: Der Held schlägt und schießt dorthin, wo der Mauszeiger steht (in den Einstellungen auf automatisches Zielen umstellbar). Ein Klick ist ein leichter Angriff. Hältst du die Taste gut eine halbe Sekunde und lässt los, folgt ein schwerer Angriff: mehr als doppelter Schaden, kurze Betäubung, kostet Ausdauer. Der Bogen verbraucht Pfeile.\n\nRüstung gibt es bei Hilda als Helm, Brust und Stiefel in drei Güten; man sieht sie an der Färbung der Figur.\n\nBlocken fängt einen Teil des Schadens ab und kostet Ausdauer. Mit Schwert und Schild blockst du am besten. Ausweichen macht dich einen Moment unverwundbar.\n\nÜber jedem Gegner siehst du Namen und Leben, oben in der Mitte groß den nächsten Gegner. Fliehst du weit genug, kehren Gegner um und heilen sich."],
	["klassen", "Klassen und Fähigkeiten", "Ritter: zäh, blockt am besten. Wirbelhieb, Schildstoß, Kampfschrei.\nBarbar: höchster Nahkampfschaden. Wirbelsturm, Erdspalter, Raserei.\nMagierin: Fernkampf mit Feuer, kann sich heilen. Frostnova, Kettenblitz, Heilung.\nSchurkin: schnell, viele kritische Treffer. Dolchfächer, Schattenschritt, Rauchbombe.\nWaldläufer: Bogen, hält Gegner fern. Pfeilsalve, Fußangel, Adlerauge.\n\nFähigkeiten kosten Mana und haben eine Abklingzeit. Die erste beherrschst du von Anfang an, die anderen lernst du mit Talentpunkten (Taste C)."],
	["werte", "Stufen, Attribute, Talente", "Erfahrung gibt es für besiegte Gegner, erledigte Aufgaben, Training und Lesen. Jede Stufe bringt 3 Attributspunkte und 1 Talentpunkt (Taste C).\n\nStärke: Schaden mit schweren Waffen\nGeschick: Ausdauer, kritische Treffer, Schaden mit Bogen und Dolchen\nIntelligenz: Mana, Schaden mit dem Zauberstab\nVitalität: Leben und Schutz\n\nAttribute kannst du auch trainieren: Übungspuppe, Zielscheibe und Steine neben deinem Haus, Bücher im Haus. Jede Einheit dauert eine Stunde und macht müde und hungrig.\n\nTalente sind dauerhafte Vorteile, jedes hat fünf Ränge."],
	["leben", "Essen und Schlafen", "Sättigung und Wachheit sinken mit der Zeit. Unter einem Viertel wirst du schwächer und langsamer, bei null Sättigung verlierst du Leben. Bist du satt und ausgeruht, machst du 10 % mehr Schaden.\n\nEssen: kaufen (Krämerladen, Wirtshaus), finden (Wildgemüse auf den Wiesen, Kisten, Beute), angeln, kochen (Herd im Haus, Feuerstelle am Dorfplatz). Am eigenen Tisch gegessen wirkt eine Mahlzeit stärker.\n\nSchlafen: im eigenen Bett am besten, sonst im Gästebett des Wirtshauses für 10 Gold. Der Schlaf heilt, füllt Mana und speichert das Spiel. Bänke und Sessel bringen eine kleine Erholung.\n\nNachts ist es dunkel. Eine Fackel (Taste T) hilft, sie brennt sechs Stunden."],
	["schmiede", "Schmiede und Runen", "Hilda verbessert jede Waffe und deinen Schutz bis +10. Das kostet Gold und Eisenerz und wird mit jeder Stufe teurer. Alle drei Stufen ändert die Waffe ihr Aussehen.\n\nIn der Schmiede kaufst du auch neue Waffen. Am Schleifstein kannst du einmal am Tag schärfen (+10 % Schaden bis zum Morgen).\n\nAb einer Waffe +5 setzt Hilda eine Rune ein (1 Glutsplitter, 100 Gold): Feuer für mehr Schaden, Frost friert Gegner manchmal ein, Blitz bringt mehr kritische Treffer.\n\nHilda arbeitet erst für dich, wenn du ihr das Erz für ihre Aufgabe gebracht hast."],
	["haus", "Dein Zuhause", "Dein Haus steht westlich des Brunnens (auf der Karte blau beschriftet). Drinnen:\n\nBett: schlafen und speichern\nTruhe: Dinge lagern\nHerd: kochen\nTisch: essen mit Bonus\nSessel: ausruhen\nBücherregal: Intelligenz trainieren\nWaffenständer: Waffen den Slots zuweisen\nTagebuch: speichern\n\nNeben dem Haus liegt der Übungsplatz. Hast du jemanden geheiratet, wohnt die Person mit dir hier."],
	["dorf", "Dorfbewohner", "Die Bewohner haben keinen festen Stundenplan. Jeder hat Hunger, Müdigkeit, Lust auf Gesellschaft und Laune und entscheidet danach selbst: arbeiten, essen, plaudern, ins Wirtshaus, spazieren, schlafen. Nachts liegen sie in ihren Betten, du kannst sie wecken, beliebt macht das nicht.\n\nIm Gespräch: Aufgaben annehmen, handeln, plaudern, nach ihrer Geschichte fragen, Geschenke machen. Jeder hat Lieblingsgeschenke. Die Zuneigung steht oben im Gesprächsfenster."],
	["liebe", "Flirten und Liebe", "Umwerben kannst du Hilda, Mira, Elara, Finn und Tomas.\n\nZuneigung wächst durch tägliche Gespräche, Plaudern, Geschenke und ihre Aufgabe.\n\nFlirten (ab 40): Du wählst einen Ton und dann einen Spruch. Charmant ist sicher, verwegen bringt mehr und kann danebengehen, heiß (ab 80) am meisten. Jeder hat einen Geschmack: Die einen mögen Witz, andere Poesie, andere klare Worte. Achte auf die Antworten. Drei Versuche am Tag.\n\nAb 60: zum Abend am Brunnen einladen. Ab 70: küssen. Ab 85: Antrag mit dem Verlobungsring aus dem Krämerladen. Danach wohnt ihr zusammen."],
	["welt", "Die Welt", "Aschfurt liegt in der Mitte. Wege führen vom Brunnen in alle Richtungen, an den Dorfausgängen stehen Wegweiser.\n\nNordwesten: Dämmerwald mit dem Schrein der Glutwacht\nOsten: die alte Mine (Eisenerz)\nNorden: die Ruinen und der Aschenritter\nSüden: der Sumpf\nSüdosten: das Fischerdorf Weidenau am See\nFerner Westen: der alte Friedhof\nFerner Nordosten: der Wachturm; von dort führt der Bergpfad nach Hochwacht\n\nDrei weitere Dörfer liegen auf eigenen Karten und sind nur per Reise erreichbar: Salzhafen (Schiff ab dem Steg in Weidenau, 15 Gold), Hochwacht (Bergpfad am Wachturm) und Dornfeld (Kutsche am Südtor von Aschfurt, 10 Gold). Jedes hat ein Wirtshaus, Händler, eigene Aufgaben und eine Glutschale für die Schnellreise. Die große Karte zeigt nur das Umland von Aschfurt\nÄußerster Norden: der Bergpass mit dem Aschentor. Dahinter liegen die Aschenlande (Akt II) und der Aschenthron (Akt III).\n\nDungeons (auf der Karte violett): die alte Mine, die Gruft unter dem Friedhof, der Turmkeller. Dort ist es finster, es gibt Fallen, Hebel für Tore, einen Endgegner und einen Schatz.\n\nJe weiter draußen, desto stärker die Gegner. Besiegte Gegner kehren nach zwei Tagen zurück. Die Karte (M) zeigt Lager als rote Kreuze und Aufgabenziele als Rauten."],
	["hof", "Haus, Garten, Berufe", "Möbel für dein Haus kaufst du im Krämerladen, sie erscheinen sofort an ihrem Platz. Die Werkbank macht aus Holz und Eisenerz Pfeile.\n\nGarten: Neben deinem Haus liegen sechs Beete. Saat gibt es im Krämerladen. Eine Pflanze braucht zwei Tage, Regen beschleunigt, im Winter wächst nichts. Jede Ernte bringt drei Stück.\n\nHühnerstall: Tomas verkauft Hühner. Jedes legt morgens ein Ei.\n\nBerufe steigen durch Ausüben (Fenster Charakter, Taste C): Kochen (Chance auf doppelte Portion), Angeln (besserer Fang), Holzfällen am Holzplatz (mehr Holz), Schmieden (billigere Verbesserungen).\n\nKalender: Eine Jahreszeit dauert sieben Tage. Am vierten Tag ist Markttag (20 % Nachlass bei allen Händlern), am ersten Tag jeder Jahreszeit feiert Aschfurt abends ein Fest auf dem Dorfplatz.\n\nWetter: Regen, Nebel, Gewitter und Schnee senken die Sicht (auch die der Gegner), die Dorfbewohner bleiben dann lieber drinnen.\n\nGlutschalen: Jede entzündete Schale ist ein Reiseziel. An einer brennenden Schale kannst du zu jeder anderen reisen."],
	["handel", "Handel, Ruf, Turnier", "Preise: Jede Ware kostet in jedem Dorf anders. Fisch ist in Salzhafen und Weidenau billig, in Hochwacht teuer. Erz ist in Hochwacht billig, in Dornfeld teuer. Gemüse, Brot und Käse sind in Dornfeld billig. Wer billig einkauft und anderswo verkauft, verdient gut.\n\nTraglast: Du trägst 60 Stück (Pfeile zählen nicht). Darüber bist du überladen und langsamer. Kutscher Veit in Dornfeld verkauft einen Packesel, mit ihm sind es 160.\n\nRuf: Jede erledigte Aufgabe hebt deinen Ruf im Dorf des Auftraggebers. Ruf senkt dort die Preise (bis 20 %), ab Ruf 30 gibt es besondere Waren, und manche Aufgaben bekommst du erst mit etwas Ruf.\n\nTurnier: Auf dem Turnierplatz von Dornfeld trittst du für 30 Gold Startgeld gegen vier Runden an. Jede Runde bringt Preisgeld, der Sieg über den Turniermeister den Titel „Meister von Dornfeld“.\n\nAlchemie: Am Alchemietisch in Elaras Studierstube braust du Tränke aus Heilkraut (wächst wild), Glutblumen, Knochenmehl, Fleisch und Fisch.\n\nSchatzkarten: selten bei Gegnern, in Salzhafen zu kaufen. Im Inventar lesen, dann zum Kreuz auf der Karte gehen und mit einer Schaufel (Krämerladen) graben.\n\nUnterwegs: Abseits der Dörfer triffst du manchmal auf Reisende in Not. Nachts streifen Schattenwölfe und Irrlichter umher, stärker als die Gegner des Tages.\n\nSchwierigkeit: leicht, normal oder schwer, bei der Charaktererstellung und in den Einstellungen."],
	["cheats", "Cheats", "F1 öffnet das Cheat-Menü. Einzeln schaltbar: Gottmodus (unverwundbar), unendlich Ausdauer und Mana, kein Hunger und keine Müdigkeit, jeder Schlag besiegt den Gegner. Dazu Knöpfe für Gold, Stufen, Heilung, Erz und Zeit."],
]

## Flirtsprüche des Helden: je Ton drei Arten (witz, poesie, direkt), je Art mehrere zur Auswahl.
const FLIRT := {
	1: {"witz": ["Ich wollte eigentlich nur Brot kaufen. Jetzt stehe ich hier und habe vergessen, was Brot ist.", "Wenn Lächeln Gold wäre, müsstest du Steuern zahlen."],
		"poesie": ["Seit ich dich kenne, kommt mir der Dämmerwald heller vor.", "Die Glut im Schrein ist warm. Aber sie hat nicht deine Augen."],
		"direkt": ["Ich mag dich. Das wollte ich gesagt haben, bevor mir wieder ein Skelett dazwischenkommt.", "Du gefällst mir. Sehr sogar."]},
	2: {"witz": ["Ich habe heute sechs Skelette erschlagen und keines hat mich so aus der Fassung gebracht wie du.", "Ist das dein Herz, das so klopft, oder schmiedet Hilda wieder?"],
		"poesie": ["Wenn ich die Augen schließe, sehe ich dich. Das ist im Kampf unpraktisch und sonst sehr schön.", "Ich würde jede Schale im Land entzünden, nur damit du es abends warm hast."],
		"direkt": ["Ich denke an dich, wenn ich allein am Feuer liege. Öfter, als ich zugeben sollte.", "Komm näher. Ich will wissen, ob du so gut riechst, wie ich glaube."]},
	3: {"witz": ["Mein Bett ist für zwei gebaut. Ich schlafe seit Wochen ineffizient.", "Ich habe eine Rüstung an, und trotzdem ziehst du mich mit Blicken aus. Unverschämt. Mach weiter."],
		"poesie": ["Deine Haut im Feuerschein. Davon träume ich, und ich wache jedes Mal zu früh auf.", "Heute Nacht will ich keinen Stern zählen außer denen in deinen Augen, und die aus nächster Nähe."],
		"direkt": ["Ich will dich. Nicht irgendwann. Heute Nacht.", "Sag ein Wort, und ich trage dich über die Schwelle, bevor die Kerze heruntergebrannt ist."]},
}
## Was die Person mag, und ihre Antworten je Ton, wenn der Spruch ankommt.
const FLIRT_ANTWORT := {
	"hilda": {"mag": "direkt", 1: ["Endlich mal einer, der nicht drum herumredet.", "Hm. Das höre ich gern. Sag es ruhig öfter."],
		2: ["Vorsicht. Wer so redet, den lasse ich nicht mehr vom Amboss weg.", "Mir wird warm, und die Esse ist aus. Das bist du."],
		3: ["Ich habe den ganzen Tag Eisen gebogen. Jetzt will ich sehen, ob du auch nachgibst.", "Dann rede nicht. Meine Hände sind rau, aber sie wissen, was sie tun."]},
	"mira": {"mag": "witz", 1: ["Charmant und pleite, meine liebste Kundschaft.", "Dafür gibt es keinen Rabatt. Aber ein Lächeln, das ist mehr wert."],
		2: ["Du handelst gut. Ich bin kurz davor, mich unter Preis herzugeben.", "Noch so ein Satz, und ich schließe den Laden früher."],
		3: ["Für heute Nacht mache ich dir ein Angebot, das du nicht ablehnst. Lieferung frei Haus.", "Ich nehme Bezahlung in Küssen. Du schuldest mir schon eine ganze Menge."]},
	"elara": {"mag": "poesie", 1: ["Das war beinahe ein Vers. Ich schreibe ihn auf.", "Du redest, als hättest du mehr gelesen, als du zugibst."],
		2: ["Mir fehlen selten die Worte. Jetzt gerade fehlen sie mir.", "Lies mir das heute Abend noch einmal vor. Leise. Ganz nah."],
		3: ["Ich habe Bücher über das Feuer gelesen. Keines hat mich vorbereitet auf das hier.", "Lösch die Kerze. Was ich dir zeigen will, steht in keinem Buch."]},
	"finn": {"mag": "direkt", 1: ["Du sagst, was du denkst. Das ist selten. Das mag ich.", "Na, das trifft. Und ich weiche sonst jedem Pfeil aus."],
		2: ["Im Wald wäre ich dir jetzt schon nachgegangen.", "Ich bleibe nie lange irgendwo. Bei dir vergesse ich zu gehen."],
		3: ["Ich kenne eine Lichtung, da findet uns bis morgen niemand.", "Ich jage sonst. Heute lasse ich mich fangen. Streng dich nicht zu sehr an."]},
	"tomas": {"mag": "witz", 1: ["Ha! Jetzt werde ich rot wie meine Tomaten.", "Du bringst mich zum Lachen. Das schafft sonst nur Bertha, und die meint es nie nett."],
		2: ["Wenn du so weitermachst, vergesse ich die Ernte. Und ich vergesse nie die Ernte.", "Ich habe starke Arme vom Pflügen. Wäre schade, sie nur für Rüben zu nutzen."],
		3: ["Im Heu ist es warm, und die Leiter ziehe ich hoch.", "Ich stehe mit der Sonne auf. Morgen ausnahmsweise nicht, wenn du bleibst."]},
}
const FLIRT_ANTWORT_2 := {
	"nele": {"mag": "witz", 1: ["Das war besser als jeder Fang heute.", "Du bringst mich zum Lachen. Dafür gibt es den Fisch günstiger. Fast."],
		2: ["Vorsicht, bei mir beißt du schneller an, als dir lieb ist.", "Sag das noch mal, wenn die Kundschaft weg ist."],
		3: ["Ich kenne eine Bucht, da kommt bei Flut niemand hin. Und niemand weg.", "Ich habe heute Abend nichts vor außer dir."]},
	"bjarne": {"mag": "direkt", 1: ["Gerade heraus. So mag ich das.", "Hm. Du gefällst mir auch. So. Jetzt ist es gesagt."],
		2: ["Komm an die Esse. Da ist es warm, und ich bin es auch.", "Wenn du so redest, verbrenne ich mir noch die Finger."],
		3: ["Der Schnee draußen liegt hoch, und mein Bett ist breit.", "Dann zeig mir, ob du so viel aushältst wie mein Stahl."]},
	"rosalind": {"mag": "poesie", 1: ["Das war schöner als jeder Strauß, den ich heute gebunden habe.", "Sprich weiter. Ich höre mit dem ganzen Gesicht zu."],
		2: ["Du weißt, dass rote Rosen etwas bedeuten? Ich binde dir gerade welche.", "Mir zittern die Hände, und das liegt nicht an den Dornen."],
		3: ["Hinter dem Rosenfeld sieht uns nur der Mond, und der kann schweigen.", "Pflück mich. Ich habe lange genug nur geblüht."]},
}
const FLIRT_KORB := {
	1: ["Nett gemeint. Aber das war nicht ganz mein Ton.", "Hm. Übe das noch einmal."],
	2: ["Langsam, langsam. So weit sind wir noch nicht.", "Das war mir zu forsch. Frag mich später noch einmal anders."],
	3: ["He! Benimm dich. Dafür kennen wir uns noch nicht gut genug.", "Das ging zu weit. Ich brauche einen Moment."],
}
const TON := {1: "Charmant", 2: "Verwegen", 3: "Heiß"}
const KUSS := {
	"hilda": "Hilda packt dich am Kragen und küsst dich, kurz und fest, wie ein Hammerschlag. Dann grinst sie.",
	"mira": "Mira schaut sich um, ob jemand zusieht, und küsst dich dann genau deshalb besonders lange.",
	"elara": "Elara nimmt die Brille ab, legt das Buch weg und küsst dich so vorsichtig, als könntest du verlöschen.",
	"finn": "Finn zieht die Kapuze zurück, sieht dich einen Atemzug lang an und küsst dich, als hätte er lange darauf gezielt.",
	"tomas": "Tomas wischt sich erst die Hände an der Hose ab. Dann küsst er dich, warm und ohne jede Eile.",
	"nele": "Nele zieht dich hinter den Marktstand, lacht, und ihr Kuss schmeckt nach Salz und Wind.",
	"bjarne": "Bjarne legt den Hammer weg. Seine Hände sind rußig, und er küsst dich so behutsam, als wärst du aus Glas.",
	"rosalind": "Rosalind steckt dir eine Blüte hinters Ohr, betrachtet ihr Werk und küsst dich, als hätte sie das schon lange so geplant.",
}
