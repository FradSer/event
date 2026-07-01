#!/usr/bin/env node
process.stdout.write(JSON.stringify({ receivedArgs: process.argv.slice(2) }));
