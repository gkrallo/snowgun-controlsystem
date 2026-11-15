# Utkast: mejl till leverantören om läs-only-konto

Inte skickat. Kristian skickar själv. Förra mejlet gick 1 november till
`fabrice.clerc@…`; adresserna `contact@…` och `f.clerc@…` på samma domän är
gissningar att prova. Bifoga `probe/skapa-lasonly-konto.sql`.

---

**Subject:** Lidköping (LIDKOPING2) – read-only database account, and three things we noticed

Bonjour Fabrice,

Thank you again for the software upgrade at the end of October. The system
has been running without problems since then.

I am following up on my email of 1 November about reading operating data from
the control PC. We have now looked at the PC ourselves, strictly read-only,
and I would like to ask for your help with one thing and your opinion on a
few others.

**1. A read-only SQL account**

We would like to show the plant status (guns, pump house, alarms) to our snow
group in a small web app. The idea is a small script on the control PC that
only runs SELECT queries every 20 seconds and sends the values out over
HTTPS. Nothing is opened towards the internet, nothing is written to the
database, and the app cannot start, stop or change anything.

To do this safely we need a login that can only read. We made a one-off
inventory using the existing GSS_Login account (read-only queries, about six
minutes, nothing written), but we do not want to leave a script running with
an account that can write. GSS_Login cannot create logins, and we do not have
the `sa` password.

Could you either

- run the attached script `skapa-lasonly-konto.sql` (it creates one login
  with `db_datareader` in the `Live_*` databases, nothing else), or
- give us the `sa` password so that we can run it ourselves?

If you see any risk in this for GSSystem, or prefer another way, please tell
us – it is your system and we do not want to disturb it.

**2. Two questions about the data**

- Lake level: the screen shows "Lake lvl. 95,5 m" and the statistics column
  `niveau_lac` is constantly 1. Is there a level sensor in our installation,
  or is that a fixed text?
- Which fields in `Water departure_Com` and `SGC400_Com` hold the measured
  water flow? With the plant stopped we cannot tell them apart.

**3. Things we noticed, for your information**

- SQL Server has no memory limit (`max server memory` is at its default) on a
  PC with 8 GB RAM. It was using 2.4 GB with 0.9 GB free. On 24 December 2022
  the logs show "insufficient system memory" errors and 868 SMS controller
  timeouts during two hours. Would you recommend setting a limit?
- Gun n°7 (S ACCESS 300, address 9) reports −25.2 °C and 15 % humidity.
- The second SGC300 (n°2) has not communicated since October 2022. Can it be
  removed from the configuration, or should we leave it?

Merci beaucoup, and best regards,

Kristian Pettersson
Lidköpings Vintersportklubb, snow group
