# My Scripting Portfolio Showcase

Hey there! I'm **LelouchLamperouge (LelouchTheory) on Roblox / lelouchvibritannia88 on Discord**. Welcome to my portfolio repository.

This folder contains a few of the core systems I've developed, demonstrating my ability to write optimized, secure, and well-structured code on Roblox.

Here is a quick breakdown of what each script in this folder does:

### 1. Server Bootstrapper (`Server (Server).lua`)
This is the main initialization script for the server. It handles the boot process in a strict, specific order to ensure dependencies load correctly. It sets up `Cmdr` for admin commands (including custom permission hooks checking group ranks) and manages remote events for things like shop purchases. It acts as the backbone that ties all my backend services together.

### 2. CENSOR Anti-Cheat Core (`CensorStandalone (ModuleScript).lua`)
This is my custom server-side anti-cheat and security system (CENSOR v8.0). Rather than instantly banning players for minor lag spikes, it uses a "Confidence Engine" that builds up a flag level over time. It monitors physics anomalies like:
- Teleportation & WalkSpeed exploits
- Jump spamming
- Suspicious flight / airtime

It also fully integrates with DataStores for temp/perm bans, allows moderators to manually flag players, and emits webhook alerts to Discord when suspicious activity happens.

### 3. CENSOR Configuration (`Configuration (ModuleScript).lua`)
A clean, dedicated config file for the CENSOR system. It lets you easily tweak variables like distance tolerances (to account for ping), decay rates for the confidence engine, punishment types, and group IDs for admin exclusions without having to dig through the main code.

### 4. Animated Poster Manager (`Manager (ModuleScript).lua`)
An optimized system I made for animating decals in the world (like digital signs or posters). Instead of a naive `while true do` loop, it:
- Tracks client FPS and scales animation speed to keep it looking smooth.
- Checks distance from the player and completely pauses animations when they are too far away (culling) to save client performance.
- Automatically handles garbage collection when decals are destroyed.

### 5. Poster Effects Initializer (`PosterEffects (LocalScript).lua`)
This works hand-in-hand with the Manager. It runs on the client, scans the workspace for specific animated decals, preloads all the required texture assets in the background, and feeds them into the Manager to start animating them.

---
*Feel free to reach out to me on Discord or Roblox if you have any questions about my work!*
