# Distributed computing with Ray

*[Nederlands](../nl/ray.md) · [back to the procedure](README.md)*

> **This page is still being written.** Ray does run here, but the instructions
> that belong on this page have not been checked against this cluster yet. If
> you use Ray and want to help, mail
> [compute@kdg.be](mailto:compute@kdg.be).

[Ray](https://docs.ray.io/) spreads Python work across several machines. On a
Slurm cluster that usually goes like this: you request a number of nodes
through Slurm, start a temporary Ray cluster on them, and your script talks to
that. When your job ends, the Ray cluster disappears with it.

What still needs to go here:

- whether Ray is available or you add it yourself with `uv add ray`
- a "hello Ray" example that shows how many machines your work runs on
- a job script that starts the head node and attaches the workers to it
- how your script connects
- how many nodes and cores make sense on `defq`
- what to know about ports between the nodes

Until then: [Submitting work with Slurm](slurm.md) describes how to put work in
the queue, which is the foundation this builds on.
