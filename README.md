[bpcmusic's telex](https://github.com/bpcmusic/telex/blob/master/commands.md) modules helped me develop a musical perspective. I want to bring some of that straightforward control to Norns.

This mod grants control over TXO+'s core features in the params menu. Good for solving all sorts of problems. 

There's a wild undocumented feature on the triggers that lets create event sequences. 

Telex forever 🙇

### In Maiden
`;install https://github.com/brokyo/norns-telexo`

### Trigger Options
- Four independent trigger sections with **clock mod** and **probability** settings
- Can be **pulsed**, **strummed**, or **burst**
- Paramquencer for scheduling parameter changes. Very, very alpha.
 
### CV Options
- Four independent CV controls supporting **LFOs** or **Tuned Oscillators** 
- Each CV port has individual control over **time**, **depth**, **phase**, **waveshape**, **rectification**

### Using It
- Once you load a script the CV and TR ports will be selectable in the PARAMS menu under the TELEXo heading.
- In CV `Mode` flips between “LFO” and “Oscillator” and shows the associated params
- CV `Type` intepolates between sine (0) > triangle (100) > saw (200) > pulse (300) > noise (400)

