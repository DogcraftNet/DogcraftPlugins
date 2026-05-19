# Passive DCD

This plugin pays all the players the configured basic rate of DCDs every hour,
multiplied by the percentages given by all the currently activated **boosts**
on the web site.

## Dependencies

This plugin depends on [Vault](https://www.spigotmc.org/resources/vault.41918/)
and on [ClockScheduler](https://github.com/Brianetta/ClockScheduler).

## Configuration   

Default configuration file:

```yaml
#Config file for PassiveDCD.
# This is the effective base HOURLY rate, regardless of frequency
Payment_Amount: 10
# Minutes past the hour at which the players are paid (list)
Minutes_Past: [0]
Update_Time: 1

#Color Codes will work using '&'.
MsgPrefix: "&c[DogCraft]&b"
#%s will replace with the (formatted) payment defined in Payment_Amount. will also adjust if a boost is applied.
MsgForReward: "You have been awarded %s for your time played on the server!"
AccumulatedPayments: {}
```

- `Payment_Amount` is the base rate of DCDs that are paid to players if there are no boosts.
- `Minutes_Past` is a list of times at which players will be paid. By default,
`[0]` means that all players will be paid on the hour. To pay players every
half an hour, use `[0,30]` or `[15,45]`. To pay them every 20 minutes, use `[0,20,40]`.
Note, this **does not** change the effective hourly rate. For example, with no boosts,
if `Payment_Amount: 10` and `Minutes_Past: [0,30]` then (without boosts) players will
be paid 5 DCDs each half an hour. 
- `Update_Time` isn't set by default. If it's added to the config, the plugin will
(quitly)check with the website for updated boosts on that interval in minutes.
It works best with factors of 60, because it uses the modulus of the current minutes.
- `Msg_Prefix` is the text to be prepended to the plugin's broadcasts. You can insert
color codes with &.
- `MsgForReward` the the text given each hour (by default) when players are paid. The
%s is replaced with the payment amount.
- `AccumulatedPayments` is a list of stored amounts of DCDs earned by players who are
not currently online. It is maintained by the plugin.

## Behaviour

The plugin uses the join and leave time of players, and the shutdown time of the server,
to calculate how long each player has been on the server. In parallel, it keeps track
of the current boost rate from the database.

Players are paid, by default, at the top of the hour, every hour. If a player is not
online when the payment run takes place, but they have already accrued paid time on
the server, they will be paid the next time that they are online during a payment run.

Time spent on the server is measured against the real time clock, not against ticks
played on the server.    

## Commands

- `activateboost` fetches an up to date list of activated boosts from the web API
- `reload` reloads the configuration from `config.yml`
- `paymentrun` makes an unscheduled payment run
- `boost` tells the player the current boost rate, and how much they have accumulated
since the last payment.