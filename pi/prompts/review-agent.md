Spawn a pi agent in a new mux vertically stacked pane and have it review your work

Run `but review <but-cli-ids...>` in a new mux pane. Wait for completion,
assess and report its findings. Leave the pane open.

Also, using `mux send-keys` send a second prompt to the agent telling it to run
a `mux send-keys` command back to your session that'll notify you when its
review is done. Have it save its findings to a file in /tmp. Send the exact
command the agent should run. This prevents you having to poll the agent. Send
this second prompt right away. Give the agent no additional instructions than
this. When you receive the file in /tmp, close the review agent pane, and print
its findings verbatim so I can see it and give me your thoughts.

Use the same window as you're currently in
