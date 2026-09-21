# Verdeeld rekenen met Ray

*[English](../en/ray.md) · [terug naar de procedure](README.md)*

> **Deze pagina is nog in de maak.** Ray draait hier wel, maar de instructies
> die hier horen te staan zijn nog niet nagekeken op deze cluster. Gebruik je
> Ray en wil je meehelpen, stuur dan een mail naar
> [compute@kdg.be](mailto:compute@kdg.be).

[Ray](https://docs.ray.io/) verdeelt Python-werk over meerdere machines. Op een
cluster met Slurm gaat dat meestal zo: je vraagt via Slurm een aantal nodes
aan, start daar een tijdelijke Ray-cluster op, en je script praat daarmee. Als
je job klaar is, verdwijnt die Ray-cluster weer.

Wat hier nog moet komen te staan:

- of Ray klaarstaat of je het zelf toevoegt met `uv add ray`
- een "hallo Ray"-voorbeeld dat toont op hoeveel machines je werk draait
- een jobscript dat de head-node start en de workers daaraan koppelt
- hoe je script verbinding maakt
- hoeveel nodes en cores zinvol zijn op `defq`
- wat je moet weten over poorten tussen de nodes

Tot zolang: [Rekenwerk indienen met Slurm](slurm.md) beschrijft hoe je werk in
de wachtrij zet, en dat is de basis waar dit bovenop komt.
