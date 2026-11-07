# Ultimo Piano

Piccolo FPS roguelite con elementi RPG, realizzato con Godot 4.2 o successivo. Dopo un turno interminabile, un impiegato deve attraversare i piani di un palazzo d'uffici infestato per riuscire a tornare a casa. Il percorso cambia a ogni partita; recupera armi e rottami, migliora l'equipaggiamento e fatti strada fino all'uscita. Il progetto non richiede asset o plugin esterni: ambienti, nemici, armi e interfaccia sono creati dal progetto.

## Avvio

1. Apri Godot.
2. Seleziona **Importa** e scegli il file `project.godot` in questa cartella.
3. Premi **F5** per avviare il progetto.

Per una guida all'architettura e a tutti gli script, consulta [la documentazione del codice](./CODE_DOCUMENTATION.md).

## Comandi

- **W A S D**: muovi
- **Mouse**: mira (se il cursore e visibile, fai clic per riprendere il controllo)
- **Tasto sinistro**: spara (tieni premuto per il fuoco automatico)
- **Tasti 1, 2, 3**: seleziona le armi gia trovate
- **Spazio**: salta
- **Esc**: libera il mouse; fai clic nella finestra per riprendere la mira

Ogni discesa genera un percorso diverso attraverso tre piani, ciascuno composto da sei stanze. Sconfiggi le presenze che infestano gli uffici per trovare le chiavi e aprire le porte; potrai scendere al piano successivo solo dopo aver liberato tutte le stanze del piano corrente. Inizia con la pistola e cerca carabina e cannone, segnalati da luci e cartelli, all'inizio dei piani successivi.

I proiettili si fermano quando colpiscono un nemico o una parete. I nemici lasciano rottami: puoi usarli nell'ufficio manutenzione dopo aver liberato una stanza per creare equipaggiamento.

Supera i tre piani e sconfiggi il Direttore nell'ultima stanza per raggiungere l'uscita e tornare a casa.
