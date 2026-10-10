Spawn a pi agent in a new mux vertically stacked pane and have it review your work.

Read the `mux` skill.

Run `but review <but-cli-ids...>` in a new mux pane.

Also, 5 seconds after running `but review`, use `mux send-keys` to send a
second prompt to the agent saying that it MUST (say MUST to it) use `mux
send-keys` command back to your session when its review is done. Have it save
its findings to a file in /tmp. Send the exact command the agent should run.
This prevents you having to poll the agent. Send this second prompt right away.
Give the agent no additional instructions than this. When you receive the file
in /tmp, close the review agent pane, and print its findings verbatim so I can
see it and give me your thoughts.

Use the same window as you're currently in
