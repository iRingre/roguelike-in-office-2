# Documentazione del codice

Questa guida descrive l'organizzazione e il comportamento del codice di **Ultimo Piano**: script GDScript, scene Godot e configurazione del progetto. I percorsi `res://` sono relativi alla cartella principale del progetto.

## Panoramica

Il progetto e un FPS 3D realizzato con nodi e risorse standard di Godot. La scena principale genera l'edificio, crea il giocatore e collega la logica di gioco all'interfaccia. Nemici e giocatore sono scene riutilizzabili; proiettili, stanze, oggetti da raccogliere e HUD vengono invece costruiti in larga parte via script.

La partita comprende tre piani con sei stanze ciascuno. Le connessioni fra le stanze di ogni piano sono generate casualmente; le uscite fra i piani conducono sempre dall'ultima stanza di un piano alla prima del successivo. Ogni stanza va liberata e la porta collegata deve essere aperta con una chiave. Dopo aver liberato tutte le 18 stanze appare il boss finale.

```text
project.godot
└── scenes/main.tscn
    └── scripts/main.gd
        ├── scenes/player.tscn ── scripts/player.gd
        ├── scenes/enemy.tscn ─── scripts/enemy.gd
        │                         └── scripts/enemy_projectile.gd
        ├── scripts/projectile.gd
        └── scripts/hud.gd
```

## Avvio e configurazione

### `project.godot`

File di configurazione Godot del progetto.

- Nome visualizzato: `Ultimo Piano`.
- Scena iniziale: `res://scenes/main.tscn`.
- Versione del formato di configurazione: `5`.
- Risoluzione base e finestra: `1280 × 720`; stretching UI con `canvas_items`.
- Rendering: renderer `gl_compatibility`, adatto alla compatibilita con OpenGL.
- Gravita 3D predefinita: `20`.
- Colore di sfondo iniziale: blu molto scuro.
- La configurazione dichiara la feature Godot `4.7`.

### Scene Godot

#### `scenes/main.tscn`

Scena minima con un nodo radice `Node3D` chiamato `UltimaLuce`, al quale e associato `scripts/main.gd`. Il mondo viene creato dinamicamente dallo script.

#### `scenes/player.tscn`

La radice `Player` e un `CharacterBody3D` con maschera di collisione `3` e script `scripts/player.gd`. I nodi figli costituiscono i riferimenti usati dallo script:

- `CollisionShape3D`: capsula fisica del giocatore.
- `Head/Camera3D`: telecamera FPS attiva, con campo visivo di 82 gradi.
- `Head/Camera3D/Weapon`: modello dell'arma visualizzato in prima persona.
- `Weapon/Body` e `Weapon/Barrel`: mesh colorate in base all'arma selezionata.
- `Weapon/MuzzleFlash`: luce breve che simula il lampo dello sparo.

#### `scenes/enemy.tscn`

La radice `Sentinella` e un `CharacterBody3D` sul layer di collisione `2`, controllato da `scripts/enemy.gd`. La capsula di collisione e i nodi `Corpo` e `Nucleo` forniscono rispettivamente la fisica e gli elementi visuali.

## Script

### `scripts/main.gd` — mondo e coordinamento della partita

E il punto di ingresso della logica di gioco. Istanzia il mondo, gestisce la progressione, collega i segnali e aggiorna l'HUD.

#### Costanti e stato

- `PLAYER_SCENE`, `ENEMY_SCENE`: scene riutilizzabili istanziate durante la partita.
- `ROOM_SIZE`, `DOOR_WIDTH`: dimensioni delle stanze e dei varchi.
- `FLOOR_COUNT`, `ROOMS_PER_FLOOR`: numero di piani e stanze per piano; insieme determinano i 18 indici stanza.
- `ROOM_CELLS`: disposizione locale delle sei stanze, espressa in celle della griglia.
- `room_centers`: centro 3D di ciascuna stanza, ordinato per piano e poi per numero stanza.
- `room_children`: elenco di stanze collegate a ciascuna stanza.
- `room_cleared`, `room_started`: stato di completamento e avvio per stanza.
- `door_barriers`, `unlocked_doors`: riferimenti alle barriere fisiche delle porte e insieme delle porte gia aperte.
- `weapon_pickups_placed`: evita di collocare piu volte le armi.
- `floor_exit_key_placed`: evita di creare piu di una chiave d'uscita per piano.
- `current_room`, `enemies_left`, `scrap`: stato della stanza attiva, nemici residui e rottami.
- `crafted_equipment`: nomi dei potenziamenti acquistati.
- `run_started`, `ending`, `boss_active`: controllano avvio, conclusione e fase del boss.

#### Ciclo di vita e generazione

- `_ready()`: inizializza il generatore casuale, crea il layout e l'arena, istanzia il giocatore, colloca le armi e crea l'HUD; collega i segnali tra giocatore, HUD e coordinatore.
- `_process(_delta)`: quando la partita e attiva, controlla la vicinanza del giocatore alle stanze collegate e chiama `_enter_room()` per avviare una stanza raggiungibile.
- `_generate_layout()`: calcola i centri delle 18 stanze, inizializza gli array di stato e crea connessioni casuali all'interno di ciascun piano con una visita in profondita. Aggiunge poi le due connessioni prestabilite fra i piani.
- `_unvisited_neighbors(room_index, visited)`: restituisce le celle adiacenti non ancora visitate dello stesso piano; e usata dal generatore per costruire il percorso.
- `_room_cell(room_index)`: converte l'indice globale della stanza nella sua coordinata di griglia.
- `_room_floor(room_index)`: converte l'indice globale nel piano, con numerazione interna da zero.
- `_room_number(room_index)`: converte l'indice globale nel numero stanza, da 1 a 6.
- `_edge_key(first, second)`: costruisce una chiave non direzionale per identificare la porta tra due stanze.
- `_room_index_at_cell(cell)`: trova l'indice della stanza alla coordinata indicata; restituisce `-1` se non esiste.
- `_has_door(first, second)`: verifica se due stanze hanno un collegamento nel layout.
- `_is_room_accessible(room_index)`: controlla che la stanza candidata sia collegata a quella corrente e che la porta sia sbloccata.

#### Costruzione del mondo

- `_build_arena()`: crea ambiente, luce direzionale, materiali condivisi e richiama `_build_room()` per tutte le stanze.
- `_build_room(...)`: crea pavimento, pareti, pilastri, arredi, cartello di piano/stanza e luce locale.
- `_build_wall(room_index, direction, offset, material, rotated)`: costruisce una parete completa o due segmenti con un varco se esiste una porta.
- `_create_door(first, second, center, rotated)`: crea mesh e collisione della porta chiusa, registrandola in `door_barriers`.
- `_add_box(node_name, position, size, material, solid)`: helper per creare una scatola visiva; se `solid` e vero aggiunge anche un corpo e una collisione statici.
- `_material(color, emission, energy)`: crea un materiale standard con colore, metallicità, ruvidita ed emissione specificati.

#### Armi, chiavi e oggetti

- `_add_weapon_pickup(room_index)`: colloca la carabina all'inizio del secondo piano e il cannone all'inizio del terzo.
- `player_weapon_count()`: restituisce il numero di armi disponibili, usato per limitare la collocazione.
- `_create_pickup(position, tint, pickup_name, value, source_room)`: costruisce un'area raccoglibile con mesh e scritta. Collega l'evento `body_entered` al gestore di chiave o arma; per una chiave conserva anche la stanza da cui parte la porta.
- `_on_key_collected(body, target_room, pickup, source_room)`: ignora corpi diversi dal giocatore, rimuove la chiave e disabilita la collisione e la mesh della porta associata. Se la chiave e di stanza, usa la stanza corrente; per le chiavi d'uscita usa la stanza sorgente esplicita.
- `_on_weapon_collected(body, weapon_index, pickup)`: rimuove l'oggetto raccolto, sblocca/equipaggia l'arma e mostra un messaggio.

#### Combattimento e avanzamento

- `_start_run()`: avvia la partita una sola volta, chiude l'introduzione, abilita i comandi e avvia la prima stanza.
- `_enter_room(room_index)`: aggiorna la stanza corrente. Se e la prima visita, calcola difficolta e numero di nemici, li dispone in cerchio, li configura e collega il segnale `defeated`.
- `_choose_enemy_kind(difficulty)`: seleziona un tipo di nemico compatibile con la difficolta; i tipi piu impegnativi vengono aggiunti nei livelli successivi.
- `_on_enemy_defeated()`: decrementa i nemici, assegna un rottame per sconfitta e aggiorna HUD. A zero nemici completa la stanza, oppure conclude la partita se e stato sconfitto il boss.
- `_on_room_cleared()`: segna la stanza come completata. Se tutte le stanze sono state liberate genera il boss; altrimenti distribuisce chiavi per le stanze ancora da visitare e apre l'interfaccia di manutenzione. Dopo il completamento di un piano intermedio rende disponibile la chiave per il piano successivo.
- `_spawn_boss()`: attiva la fase finale, crea Il Direttore nella stanza conclusiva, gli applica la configurazione boss e collega la sconfitta alla normale gestione dei nemici.
- `_place_floor_exit_key(floor_index)`: crea una sola chiave nella stanza d'uscita del piano, diretta alla prima stanza del piano successivo.
- `_floor_cleared(floor_index)`: restituisce vero solo quando tutte le sei stanze del piano sono completate.
- `_on_equipment_chosen(index)`: gestisce la scelta nell'officina. L'indice `0`, `1` o `2` compra un potenziamento al costo di tre rottami; l'indice `3` chiude l'officina e riprende l'esplorazione.
- `_unlocked_door_count()`: conta le porte aperte adiacenti alla stanza corrente.
- `_all_rooms_cleared()`: verifica che tutte le stanze siano state completate.
- `_on_health_changed(current, maximum)`: inoltra all'HUD l'aggiornamento della salute, se l'HUD e ancora valido.
- `_on_player_died()`: imposta la conclusione e mostra la schermata di sconfitta.
- `_restart_run()`: ricarica la scena principale, azzerando lo stato della partita.

### `scripts/player.gd` — giocatore e armi

Definisce la classe globale `PlayerController`, derivata da `CharacterBody3D`.

#### Segnali

- `health_changed(current, maximum)`: emesso quando cambia la salute.
- `died`: emesso quando la salute raggiunge zero.
- `weapon_changed(weapon_name, weapon_index)`: emesso quando cambia arma.

#### Dati e configurazione

- `WEAPONS`: dati di pistola, carabina e cannone, inclusi danno, intervallo di fuoco, velocita e colore.
- Le proprieta esportate `walk_speed`, `jump_velocity`, `max_health`, `shot_damage` e `fire_interval` definiscono i valori di base modificabili dall'Inspector.
- `unlocked_weapons` registra le armi raccolte; la pistola e disponibile dall'inizio.
- I riferimenti `head`, `camera`, `weapon`, `weapon_body`, `weapon_barrel` e `muzzle_flash` sono risolti tramite i nodi definiti in `player.tscn`.

#### Funzioni

- `_ready()`: inizializza salute e aspetto dell'arma e pubblica i valori iniziali con i segnali.
- `set_controls_enabled(enabled)`: abilita/disabilita il controllo e imposta la modalita del mouse.
- `_unhandled_input(event)`: gestisce mira con il mouse, fuoco singolo, cambio arma con `1`-`3` e rilascio del mouse con `Esc`.
- `_physics_process(delta)`: aggiorna cooldown, movimento WASD relativo all'orientamento, salto, gravita, movimento della telecamera/arma e fuoco automatico tenendo premuto il tasto sinistro.
- `_fire()`: controlla il cooldown, usa un raycast dalla telecamera per determinare il punto mirato, quindi crea un proiettile visivo/fisico con danno e velocita dell'arma selezionata.
- `take_damage(amount)`: applica danni solo quando il giocatore e controllabile; emette aggiornamento salute e segnale di morte.
- `upgrade_damage(amount)`, `upgrade_health(amount)`, `upgrade_speed(amount)`: applicano i tre potenziamenti dell'officina. Il potenziamento salute aumenta il massimo e recupera salute fino al nuovo limite.
- `unlock_weapon(index)`: valida e sblocca un'arma, selezionandola immediatamente.
- `weapon_name(index)`: restituisce il nome dell'arma o una stringa vuota per un indice non valido.
- `_select_weapon(index)`: seleziona solo armi sbloccate e pubblica il cambiamento.
- `_apply_weapon_appearance()`: aggiorna colore/emissione e scala della mesh dell'arma, oltre al colore del lampo.

### `scripts/enemy.gd` — nemici e boss

Definisce la classe globale `Sentinel`, anch'essa derivata da `CharacterBody3D`.

- `Kind`: enum con `HUNTER`, `RUNNER`, `BRUTE`, `SHOOTER` e `BOSS`.
- `defeated`: segnale emesso una sola volta quando la salute arriva a zero.
- `configure(enemy_kind, difficulty)`: assegna tipo, salute massima, velocita e danni in base al ruolo e alla difficolta.
- `_ready()`: registra il nemico nel gruppo `enemies`, inizializza salute, materiali e aspetto specifico, quindi cerca il giocatore nel gruppo `player`.
- `_physics_process(delta)`: aggiorna cooldown e flash del danno; i nemici da mischia inseguono e colpiscono a distanza ravvicinata. Tiratori e boss cercano di mantenere una distanza di tiro e generano proiettili.
- `take_damage(amount)`: riduce la salute, attiva il flash e, alla sconfitta, emette `defeated` e rimuove il nodo.
- `_shoot()`: istanzia un proiettile nemico diretto al giocatore.
- `_flash_material()`: restituisce il materiale chiaro usato per il feedback visivo dei colpi.

### `scripts/projectile.gd` — proiettile del giocatore

Script applicato a un nodo `Node3D` creato quando il giocatore spara.

- `setup(origin, aim_direction, hit_damage, projectile_speed, tint, shooter_rid)`: imposta posizione, direzione, danno, velocita, proprietario e mesh luminosa.
- `_physics_process(delta)`: esegue un raycast sul tratto che il proiettile percorre in questo frame. Se colpisce un nemico nel gruppo `enemies`, applica danno; in ogni caso rimuove il proiettile al primo impatto. Lo rimuove anche dopo 80 unita di distanza.
- `direction`, `speed`, `damage`, `traveled`, `max_distance`, `shooter`: stato di movimento, collisione e gittata.

### `scripts/enemy_projectile.gd` — proiettile nemico

Script per i proiettili rossi generati da tiratori e boss.

- `setup(origin, aim_direction, hit_damage, projectile_speed, shooter_rid)`: configura traiettoria, danno, velocita, esclusione del tiratore e mesh luminosa.
- `_physics_process(delta)`: esegue raycast sul tratto percorso. Se colpisce un nodo nel gruppo `player`, chiama `take_damage`; il proiettile viene rimosso al primo impatto o dopo 40 unita.
- `direction`, `speed`, `damage`, `traveled`, `shooter`: stato del proiettile.

### `scripts/hud.gd` — interfaccia e menu

Definisce la classe globale `GameHud`, derivata da `CanvasLayer`. Crea l'interfaccia via codice e comunica le azioni dell'utente al coordinatore tramite segnali.

#### Segnali

- `start_pressed`: pulsante che avvia la partita.
- `equipment_chosen(index)`: scelta di un potenziamento o del pulsante di continuazione (`3`).
- `restart_pressed`: richiesta di riavvio dalla schermata finale.

#### Funzioni

- `_ready()`: costruisce l'interfaccia e apre la schermata introduttiva.
- `_build_game_hud()`: crea etichette per salute, piano/stanza, arma, rottami ed equipaggiamento, indicazioni comandi, mirino e overlay.
- `show_intro()`: visualizza la storia iniziale e il pulsante di avvio.
- `set_room(room_index, total_floors, rooms_per_floor, unlocked_doors)`: converte l'indice della stanza in piano/stanza per aggiornare il testo HUD.
- `close_intro()`: chiude il pannello introduttivo.
- `show_message(message)`: crea un messaggio temporaneo in alto e lo rimuove dopo quattro secondi.
- `show_workshop(...)`: mostra il pannello di manutenzione con il riepilogo, i tre acquisti e il pulsante per continuare; disattiva gli acquisti che superano i rottami disponibili.
- `show_ending(victory)`: presenta la schermata di vittoria o sconfitta e il pulsante di riavvio.
- `set_health(current, maximum)`: aggiorna salute e colore di avviso quando la salute e bassa.
- `set_remaining(count)`: memorizza e mostra i nemici ancora da sconfiggere.
- `set_weapon(weapon_name, weapon_index)`: aggiorna l'arma attiva.
- `set_scrap(amount)`: aggiorna il totale dei rottami.
- `set_equipment(items)`: mostra i potenziamenti acquistati o `nessuno`.
- `_show_panel(title, text, button_text, callback, panel_height)`: helper per pannelli centrati con titolo, testo e pulsante opzionale.
- `_remove_message(box)`: rimuove il messaggio temporaneo se e ancora valido.
- `_emit_equipment_choice(index)`: inoltra la scelta dell'interfaccia tramite `equipment_chosen`.
- `close_workshop()`: chiude il pannello manutenzione.
- `_clear_panel()`: rimuove i controlli temporanei, nasconde l'overlay e ripristina il mirino.
- `_label(...)`: crea una `Label` con stile e posizione impostati.
- `_make_button(text)`: crea un pulsante con dimensione e stili standard dell'interfaccia.
- `_panel_style(background, border)`: crea lo stile condiviso per pannelli e pulsanti.

## Flusso dei segnali

1. `GameHud.start_pressed` richiama `main.gd::_start_run()`.
2. `PlayerController.health_changed` aggiorna la salute nell'HUD; `died` porta alla schermata di sconfitta.
3. `PlayerController.weapon_changed` aggiorna l'etichetta dell'arma.
4. `Sentinel.defeated` aggiorna conteggio nemici e rottami in `main.gd`.
5. `GameHud.equipment_chosen` applica un potenziamento o riattiva il giocatore.
6. `GameHud.restart_pressed` ricarica la scena principale.

## Modificare la struttura della partita

Il numero di piani e stanze e controllato da `FLOOR_COUNT` e `ROOMS_PER_FLOOR` in `scripts/main.gd`; le coordinate locali delle sei stanze sono in `ROOM_CELLS`. Cambiando questi valori occorre mantenere coerenti le connessioni generazionali, la conversione indice/piano e i testi HUD.

Le armi e i loro parametri sono definiti in `PlayerController.WEAPONS`. I valori di salute, velocita e danno per le varianti dei nemici sono definiti in `Sentinel.configure()`. Costi e risultati dei potenziamenti sono coordinati da `main.gd::_on_equipment_chosen()` e visualizzati in `GameHud.show_workshop()`.

## Esecuzione e verifica

Aprire `project.godot` con Godot e premere **F5**. Per controllare rapidamente che il progetto venga caricato da riga di comando, si puo usare:

```powershell
godot --headless --path . --quit-after 2
```
