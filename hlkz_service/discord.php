<?php
	mb_internal_encoding('utf-8');

	//phpinfo();
        $json = file_get_contents('php://input');
        $obj = json_decode($json, true);

	if (!empty($obj) && isset($obj["holder"]) && isset($obj["map"]) && isset($obj["type"]) && isset($obj["time"]) && isset($obj["webhook"])) {
		include 'discord_hook_lib.php';

		$webhook = $obj["webhook"];
		$runner = $obj["holder"];
		$runMap = $obj["map"];
		$runType = ucfirst($obj["type"]);
		$runTime = $obj["time"];
		$msg = "[HLKZ] **$runner** has now the $runType WR for **$runMap**! Finished in **$runTime**";
		$title = "Top 5 $runType [$runMap]";
		$desc = "```diff\n";
		$rec = $obj["records"];

		$top = 5;
		$maxLength = 10;
		// Get the length of the widest name to pad the other names with enough whitespaces
		for ($i = 0; $i < $top; $i++) {
			$nameLength = mb_strlen(rtrim($rec[$i]["name"]));
			if ($nameLength > $maxLength) {
				$maxLength = $nameLength;
			}
		}

		// Add the records of leaderboard to the embed description
		for ($j = 0; $j < $top; $j++) {
			if 	($j >= 3) $desc .= "--- ";
			else if ($j == 2) $desc .= "*-- ";
			else if ($j == 1) $desc .= "--+ ";
			else if ($j == 0) $desc .= "++- ";
			$desc .= ($j+1) . "  ";

			foreach ($rec[$j] as $key => $value) {
				if ($key == "name") {
					$desc .= mb_str_pad(rtrim($value), $maxLength);
				} else {
					$desc .= $value;
				}
				$desc .=  "  ";
			}
			// This is so that the date doesn't go to the next line 'cos of Discord's word wrapping
			$desc .= "           \n";
		}
		$desc .= "  \n```";

		DiscordHook::send(new Message(new User($webhook, "SourceRuns"), $msg, [new Embed($title, $desc, null, 14177041)]));
	}

	function mb_str_pad( $input, $pad_length, $pad_string = ' ', $pad_type = STR_PAD_RIGHT, $encoding="UTF-8") {
    		$diff = strlen($input) - mb_strlen($input, $encoding);
    		return str_pad($input, $pad_length + $diff, $pad_string, $pad_type);
	}
?>
