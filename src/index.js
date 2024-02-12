const config = require('./config');
const assert = require('assert');
const chalk = require('chalk');

const logger = console;

const open = require('open');
const net = require('net');
const { exec } = require('child_process');
const common = require('./common');

const { RomShuffler } = require('./swap');
const { TwitchShufflerListener } = require('./twitch')

const server = net.createServer();

const fs = require('fs').promises;

const precondition = (expression, message) => {
  try {
    assert(expression)
  } catch(e) {
    const error = new Error(message || e.message);
    throw error;
  }
}

const startBizhawk = (port, host) => {
  switch(process.platform) {
    case "win32":
      if(!process.env.session) {
        process.env.session = config.session;
      }
      open('Start_BizHawk_Listen_To_Crowd_Shuffler.bat');
      logger.info(chalk.green("Bizhawk started"));
      break;

    case "linux":
      if(!process.env.session) {
        process.env.session = config.session;
      }
      
      exec('./start-bizhawk-listen-to-crowd-shuffler.sh', (error, stdout, stderr) => {
        console.log(stdout);
        console.log(stderr);
        if (error !== null) {
            console.log(`exec error: ${error}`);
        }
      });
      logger.info(chalk.green("Bizhawk started"));
      break;

    default:
      logger.error(chalk.yellow("Script run in " + process.platform + ". Please start BizHawk manually."));

  }
};

const startServer = async () => {
  let sockets = [];

  const switchRom = (rom, cause) => {
    if(!rom) {
      return;
    }
    const romName = rom.replace(/\.[a-zA-Z]+$/, '')

    twitchShufflerListener.say(`/me Swapping to "${romName}" (${cause})`);
    message = `switchRom\t${rom}\n`;
    sockets.forEach((sock) => {
      sock.write((message.length - 1) + ' ' + message);
    });
  };

  const list = async () => {
    let roms = await romShuffler.fetchCurrentRoms();

    let filteredRoms = roms
      .map((rom) => rom.replace(/\.[a-zA-Z]+$/, ''))
      .filter(common.filterRomsFromPattern(this.ignoreRomsPattern))
      .filter((rom) => rom !== 'DeleteMe')
    ;

    let total = filteredRoms.length;

    let partition = filteredRoms;

    const join = () => {
      return partition.join(', ');
    };

    while(join().length >= 500) {
      partition.pop();
    }

    let chatText = `ExtraLife ${join()} (${total}/${total})`;

    return chatText;
  };

  const swap = async (index, cause) => {
    let rom = await romShuffler.shuffle(index);

    if(!rom || rom === '') {
      twitchShufflerListener.say(`/me No rom matches "${index}"`);
    }

    switchRom(rom, cause);
  };

  const startTimer = () => {
    if(!config.timer) {
      logger.info(chalk.blue(`Timer is disabled`));
      return;
    }

    let timeoutId =  null;

    let { min, max } = config.timer;

    logger.info(chalk.blue(`Timer is enabled between ${min / 1000} and ${max / 1000} seconds`));

    function tick() {
      swap(null, "auto timer");
      let timeout = Math.floor(Math.random() * max) + min;

      setTimeout(tick, timeout);
    }

    tick();
  };

  const romShuffler = new RomShuffler();
  const twitchShufflerListener = new TwitchShufflerListener({
    swap,
    list,
  });

  logger.info(chalk.blue(`TCP Server is starting on ${config.host} ${config.port}`));

  server.listen(config.port, config.host, async () => {

    logger.info(chalk.green(`Shuffler Server Started`));

    await startBizhawk(config.port, config.host);
    await twitchShufflerListener.start();
    await startTimer();

    server.on('connection', function(sock) {
      sockets.push(sock);

      const ping = () => {
        sockets.forEach((sock) => {
          sock.write("4 ping\n");
        });

        setTimeout(ping, 2000);
      };

      ping();

      sock.on('close', function(data) {
        let index = sockets.findIndex(function(o) {
          return o.remoteAddress === sock.remoteAddress && o.remotePort === sock.remotePort;
        })
        if (index !== -1) sockets.splice(index, 1);
        console.log('CLOSED: ' + sock.remoteAddress + ' ' + sock.remotePort);
      });
    });

    server.on('data', function(data) {
      logger.info(chalk.purple(data));
    });

    });

}

async function main() {
  try {
    await startServer();
  } catch(e) {
    logger.error(e);
    process.exit(1);
  }
}

main();
