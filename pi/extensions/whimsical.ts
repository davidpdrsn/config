// Source: https://github.com/mitsuhiko/agent-stuff/blob/main/pi-extensions/whimsical.ts
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const messages = [
  "Consulting the void...",
  "Negotiating with entropy...",
  "Waxing philosophical...",
  "Consulting ancient scrolls...",
  "Reading tea leaves...",
  "Shaking the magic 8-ball...",
  "Warming up the hamsters...",
  "Spinning up the squirrels...",
  "Caffeinating...",
  "Existentially questioning...",
  "Having a little think...",
  "Stroking chin thoughtfully...",
  "Squinting at the problem...",
  "Staring into the abyss...",
  "Abyss staring back...",
  "Achieving enlightenment...",
  "Ascending to a higher plane...",
  "Performing arcane rituals...",
  "Consulting the oracle...",
  "Divining the answer...",
  "Rearranging deck chairs...",
  "Aligning the chakras...",
  "Reticulating splines...",
  "Reversing the polarity...",
  "Calibrating the flux capacitor...",
  "Charging the crystals...",
  "Tuning the vibrations...",
  "Adjusting the cosmic frequency...",
  "Waiting for a sign...",
  "Hoping for the best...",
  "Manifesting solutions...",
  "Willing it into existence...",
  "Believing really hard...",
  "Bargaining with fate...",
  "Reading the room...",
  "Checking under the hood...",
  "Kicking the tires...",
  "Shaking loose the cobwebs...",
  "Dusting off the neurons...",
  "Greasing the gears...",
  "Oiling the cogs...",
  "Winding up the clockwork...",
  "Stoking the furnace...",
  "Reticulating the viewfinder...",
  "Adding a dash of elegance...",
  "Sprinkling some magic dust...",
  "Presenting with pizzazz...",
  "Ultrahanding...",
  "Ascending through the ceiling...",
  "Rewinding the dungeon...",
  "Fusing questionable materials...",
  "Parrying like a prince...",
  "Dashing through the Lost Crown...",
  "Gliding toward the objective...",
  "Shifting perspective dramatically...",
  "Dodging with Resident Evil inventory anxiety...",
  "Save-rooming...",
  "Revving the chainsaw politely...",
  "Stomping through dead space...",
  "Punching through the Spider-Verse...",
  "Cape-gliding over Gotham...",
  "Countering freeflow style...",
  "Shuffling the deck for a better hand...",
  "Going full Balatro brain...",
  "Poking at the Animal Well...",
  "Peering into the Outer Wilds...",
  "Looping the solar system again...",
  "Surviving vampirically...",
  "Bullet-heavening...",
  "Boosting into Armored Core speeds...",
  "S-ranking the mission...",
  "Wonder-seeding...",
  "Hifi-rushing...",
  "Plunging into the cocoon...",
  "Dredging up something suspicious...",
  "Silksonging preemptively...",
  "Herb-combining...",
  "Ink-ribboning...",
  "Managing inventory like it’s a briefcase puzzle...",
  "Opening a deeply impractical door...",
  "Investigating ominous village noises...",
  "Rolling for initiative...",
  "Checking for mimics...",
  "Consulting the Dungeon Master...",
  "Polishing the twenty-sided die...",
  "Mapping the forgotten catacombs...",
  "Listening at the dungeon door...",
  "Preparing a spell slot...",
  "Rolling a suspiciously low perception check...",
  "Splitting the party, regrettably...",
  "Befriending the tavern goblin...",
  "Searching for secret passages...",
  "Counting torches before descending...",
  "Arguing with a lawful good paladin...",
  "Negotiating with a sleepy dragon...",
  "Looting the ornate chest carefully...",
];

function pickRandom(): string {
  return messages[Math.floor(Math.random() * messages.length)];
}

export default function (pi: ExtensionAPI) {
  pi.on("turn_start", async (_event, ctx) => {
    ctx.ui.setWorkingMessage(pickRandom());
  });

  pi.on("turn_end", async (_event, ctx) => {
    ctx.ui.setWorkingMessage(); // Reset for next time
  });
}
