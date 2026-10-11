Obj
===

.. code-block:: dart

   class Obj

Compile-time string identifiers for patcher object types.

Pass any of these to [Patcher.createObject] instead of a raw
string literal; the two are interchangeable. The `~` prefix
marks DSP / audio-rate objects, `.` marks control-rate
objects. Every type in the engine registry has a constant,
named after its `YSE::OBJ` constant in upstream
`patcher/pObjectList.hpp` (`D_SINE` becomes [dSine]).

[all] lists every constant. For the full per-object schema
(inlets, outlets, parameters) use [PatcherRegistry].

Static accessors
----------------

.. code-block:: dart

   static const String dLine

``~line``: Linear-ramp generator. Ramps an audio-rate value toward a
target over a given time in ms.

.. code-block:: dart

   static const String dNoise

``~noise``: White-noise generator. Sends a new block of random samples
on every audio block.

.. code-block:: dart

   static const String dSaw

``~saw``: Audio-rate sawtooth oscillator. Frequency can be set with a
float or modulated with a DSP buffer.

.. code-block:: dart

   static const String dSine

``~sine``: Audio-rate sine oscillator. Frequency can be set with a float
or modulated with a DSP buffer.

.. code-block:: dart

   static const String dBandpass

``~bp``: Bandpass filter. Passes a frequency band centered on
'frequency' with bandwidth shaped by 'Q' (resonance).

.. code-block:: dart

   static const String dHighpass

``~hp``: Single-pole highpass filter. Attenuates content below the
cutoff frequency.

.. code-block:: dart

   static const String dLowpass

``~lp``: Single-pole lowpass filter. Attenuates content above the cutoff
frequency.

.. code-block:: dart

   static const String dVcf

``~vcf``: Resonant bandpass filter whose center frequency is a signal,
so it can sweep at audio rate. Sharpness sets how narrow the band is.

.. code-block:: dart

   static const String gReverseSubtract

``.!-``: Subtracts the left operand from the right one and sends right -
left as a float: .- with the operands the other way round.

.. code-block:: dart

   static const String gReverseDivide

``.!/``: Divides the right operand by the left one and sends right /
left as a float: ./ with the operands the other way round. A left
operand of 0 sends 0.

.. code-block:: dart

   static const String gNotEqual

``.!=``: Sends 1 when the left operand differs from the right one,
otherwise 0.

.. code-block:: dart

   static const String gModulo

``.%``: Sends the remainder of dividing the left operand by the right
one, as an int. The remainder has the sign of the left operand, and a
divisor of 0 sends 0.

.. code-block:: dart

   static const String gBitAnd

``.&``: Bitwise AND of two integers, sent as an int. Floats are
truncated toward zero first.

.. code-block:: dart

   static const String gLogicalAnd

``.&&``: Logical AND: sends 1 when both operands are non-zero, otherwise 0.

.. code-block:: dart

   static const String gMultiply

``.*``: Multiplies two numbers and sends the product as a float.

.. code-block:: dart

   static const String gAdd

``.+``: Adds two numbers. A number on the left inlet is added to the
stored right operand, and the sum is sent as a float.

.. code-block:: dart

   static const String gSubtract

``.-``: Subtracts the right operand from the left one and sends the
difference as a float.

.. code-block:: dart

   static const String gDivide

``./``: Divides the left operand by the right one and sends the quotient
as a float. Dividing by 0 sends 0.

.. code-block:: dart

   static const String gLess

``.<``: Sends 1 when the left operand is less than the right one,
otherwise 0.

.. code-block:: dart

   static const String gShiftLeft

``.<<``: Shifts the bits of the left operand left by the right operand.
A count below 0 shifts nothing, and a count of 32 or more gives 0.

.. code-block:: dart

   static const String gLessEqual

``.<=``: Sends 1 when the left operand is less than or equal to the
right one, otherwise 0.

.. code-block:: dart

   static const String gEqual

``.==``: Sends 1 when the left operand equals the right one, otherwise 0.

.. code-block:: dart

   static const String gGreater

``.>``: Sends 1 when the left operand is greater than the right one,
otherwise 0.

.. code-block:: dart

   static const String gGreaterEqual

``.>=``: Sends 1 when the left operand is greater than or equal to the
right one, otherwise 0.

.. code-block:: dart

   static const String gShiftRight

``.>>``: Shifts the bits of the left operand right by the right operand,
keeping the sign. A count below 0 shifts nothing; past 31, a negative
number gives -1 and any other 0.

.. code-block:: dart

   static const String gAbs

``.abs``: Sends the absolute value of a number, as a float.

.. code-block:: dart

   static const String gAccum

``.accum``: Stores a number you can replace, add to and multiply. A
number on the left inlet replaces it and sends it; the middle inlet adds
to it and the right inlet multiplies it, without sending.

.. code-block:: dart

   static const String gAcos

``.acos``: Sends the arc-cosine of a number, in radians. Numbers outside
-1 to 1 send 0.

.. code-block:: dart

   static const String gAcosh

``.acosh``: Sends the hyperbolic arc-cosine of a number. Numbers below 1
send 0.

.. code-block:: dart

   static const String gAnal

``.anal``: Counts how often each number follows the one before it, and
sends '\<previous\> \<current\> \<count\>' for every pair it counts.
Wire it into .prob to make .prob play in the style of what it heard.

.. code-block:: dart

   static const String gAsin

``.asin``: Sends the arc-sine of a number, in radians. Numbers outside
-1 to 1 send 0.

.. code-block:: dart

   static const String gAsinh

``.asinh``: Sends the hyperbolic arc-sine of a number.

.. code-block:: dart

   static const String gAtan

``.atan``: Sends the arc-tangent of a number, in radians. Use .atan2 for
an angle around the full circle.

.. code-block:: dart

   static const String gAtan2

``.atan2``: Sends the angle of the point (x, y) in radians, measured
from the positive x axis, from -pi to pi. The left inlet takes y and the
right inlet x.

.. code-block:: dart

   static const String gAtanh

``.atanh``: Sends the hyperbolic arc-tangent of a number. Numbers at or
beyond -1 and 1 send 0.

.. code-block:: dart

   static const String gAtodb

``.atodb``: Converts a linear amplitude to decibels on the engine's
scale, where an amplitude of 1 is 100 dB and nothing goes below 0 dB.
Subtract 100 for decibels relative to full scale.

.. code-block:: dart

   static const String gCartopol

``.cartopol``: Converts the point (x, y) to polar form: its distance
from the origin on the left outlet and its angle in radians on the right
one.

.. code-block:: dart

   static const String gChange

``.change``: Passes a number on only when it differs from the previous
one. Two more outlets report when the value leaves 0 and when it returns
to 0.

.. code-block:: dart

   static const String gClip

``.clip``: Limits a number to the range low to high and sends it as a
float. A number inside the range passes unchanged; any other becomes the
nearest limit.

.. code-block:: dart

   static const String gCos

``.cos``: Sends the cosine of an angle in radians, as a float.

.. code-block:: dart

   static const String gCosh

``.cosh``: Sends the hyperbolic cosine of a number. Beyond about -89 and
89 the result is too large for a float, and 0 is sent.

.. code-block:: dart

   static const String gCounter

``.counter``: Counts bangs. Each bang adds the step to the count and
sends the new count as an int; an int on the left inlet sets the count
and sends it.

.. code-block:: dart

   static const String gDbtoa

``.dbtoa``: Converts decibels on the engine's scale to a linear
amplitude: 100 dB is an amplitude of 1, and 0 dB or less gives 0. The
inverse of .atodb.

.. code-block:: dart

   static const String gIntDivide

``.div``: Integer division: divides the left operand by the right one
and sends the whole quotient as an int, truncated toward zero. A divisor
of 0 sends 0.

.. code-block:: dart

   static const String gExpr

``.expr``: Evaluates a C-style expression such as '$f1 \* 2 + $f2'. The
placeholders $i1-$i9 and $f1-$f9 create the inlets; the left inlet
calculates and sends the result.

.. code-block:: dart

   static const String frequencyToMidi

``.ftom``: Converts a frequency in Hz to a MIDI note number, with 440 Hz
(A4) at note 69. The result is fractional, so a detuned pitch keeps its
offset.

.. code-block:: dart

   static const String gHisto

``.histo``: Counts how often each number arrives and sends '\<number\>
\<count\>' each time. The right inlet reports a number's count without
counting it.

.. code-block:: dart

   static const String gLinedrive

``.linedrive``: Maps a number onto an exponential curve: inputMax gives
outputMax, and each step below it divides the output by the curve. Lets
a linear control, such as a MIDI controller, drive a frequency or a gain
evenly.

.. code-block:: dart

   static const String gMaximum

``.maximum``: Sends the larger of a number and a stored value. The right
inlet sets the stored value; a list sends its largest item.

.. code-block:: dart

   static const String gMean

``.mean``: Sends the average of every number received so far, and how
many numbers that is. A list sends the average of its own items and
starts the average over.

.. code-block:: dart

   static const String gMinimum

``.minimum``: Sends the smaller of a number and a stored value. The
right inlet sets the stored value; a list sends its smallest item.

.. code-block:: dart

   static const String midiToFrequency

``.mtof``: Converts a MIDI note number to a frequency in Hz, with note
69 (A4) at 440 Hz. Fractional note numbers give the frequencies in
between.

.. code-block:: dart

   static const String gPast

``.past``: Sends a bang when a number rises to or above a threshold,
then stays silent until the number drops below it again. With several
thresholds, each item of a list must reach its own.

.. code-block:: dart

   static const String gPeak

``.peak``: Keeps the largest number received so far and sends it only
when a new number beats it. Two more outlets report whether each number
set a new peak.

.. code-block:: dart

   static const String gPoltocar

``.poltocar``: Converts a polar point, a distance from the origin and an
angle in radians, to its x and y coordinates. The inverse of .cartopol.

.. code-block:: dart

   static const String gPong

``.pong``: Keeps a number inside the range low to high by folding it
back from the limits, the default, by wrapping it around to the other
side, or by clipping it. Sends the result as a float.

.. code-block:: dart

   static const String gPow

``.pow``: Raises the left operand to the power of the right one and
sends the result as a float. Combinations with no finite real result,
such as a negative base with a fractional exponent, send 0.

.. code-block:: dart

   static const String gRound

``.round``: Rounds a number to the nearest multiple of the step and
sends it as a float: a step of 1, the default, rounds to whole numbers
and 0.5 to halves. Halfway values round away from zero; a step of 0
passes the number unchanged.

.. code-block:: dart

   static const String gScale

``.scale``: Maps a number from the input range onto the output range and
sends it as a float. An exponent other than 1 bends the mapping into a
curve; numbers outside the input range map past the output range unless
clip is 1.

.. code-block:: dart

   static const String gSin

``.sin``: Sends the sine of an angle in radians, as a float.

.. code-block:: dart

   static const String gSinh

``.sinh``: Sends the hyperbolic sine of a number. Beyond about -89 and
89 the result is too large for a float, and 0 is sent.

.. code-block:: dart

   static const String gSlide

``.slide``: Smooths a stream of numbers. Each number moves the output
part of the way towards it: 1/slideUp of the distance when rising,
1/slideDown when falling. A slide of 1 passes numbers straight through.

.. code-block:: dart

   static const String gSqrt

``.sqrt``: Sends the square root of a number, as a float. A negative
number sends 0.

.. code-block:: dart

   static const String gSwap

``.swap``: Sends two numbers out in swapped order. A number on the left
inlet leaves the right outlet, then the number stored on the right inlet
leaves the left outlet.

.. code-block:: dart

   static const String gTan

``.tan``: Sends the tangent of an angle in radians, as a float. Where
the result would be infinite, it sends 0.

.. code-block:: dart

   static const String gTanh

``.tanh``: Sends the hyperbolic tangent of a number: a smooth S-curve
between -1 and 1, often used for soft saturation.

.. code-block:: dart

   static const String gTogedge

``.togedge``: Bangs the left outlet when a value becomes non-zero and
the right outlet when it returns to 0, and stays silent in between. A
bang flips the value between zero and non-zero.

.. code-block:: dart

   static const String gTrough

``.trough``: Keeps the smallest number received so far and sends it only
when a new number goes below it. Two more outlets report whether each
number set a new minimum.

.. code-block:: dart

   static const String gVexpr

``.vexpr``: Evaluates an expression for every item of a list, as .expr
does for single numbers, and sends the results as a list. A single
number on an inlet is used for every item.

.. code-block:: dart

   static const String gZmap

``.zmap``: Maps a number from the input range onto the output range, in
a straight line, and sends it as a float. A number outside the input
range gives the nearest output limit, so the result never leaves the
output range.

.. code-block:: dart

   static const String gBitOr

``.|``: Bitwise OR of two integers, sent as an int. Floats are truncated
toward zero first.

.. code-block:: dart

   static const String gLogicalOr

``.||``: Logical OR: sends 1 when either operand is non-zero, otherwise 0.

.. code-block:: dart

   static const String dMultiply

``~*``: Multiplies an audio signal by another audio signal or by a
float: a gain stage, or a ring modulator.

.. code-block:: dart

   static const String dAdd

``~+``: Adds two audio signals, or adds a float to an audio signal.

.. code-block:: dart

   static const String dSubtract

``~-``: Subtracts an audio signal, or a float, from an audio signal.

.. code-block:: dart

   static const String dDivide

``~/``: Divides an audio signal by another audio signal or by a float. A
float of 0 leaves the signal unchanged.

.. code-block:: dart

   static const String dClip

``~clip``: Hard clipper: limits every sample of an audio signal to the
range low to high. Use it to tame stray peaks, or as a distortion stage.

.. code-block:: dart

   static const String gButton

``.b``: A button. Any bang or number sends a bang and lights the button
until the host next reads it.

.. code-block:: dart

   static const String gDial

``.dial``: A knob with its own output range. It takes a position from 0
to 1 and sends it mapped onto minimum-maximum, optionally bent into a
curve by an exponent and rounded to an int.

.. code-block:: dart

   static const String gFloat

``.f``: A float number box. A number on the left inlet stores it and
sends it, a bang sends it again, and the right inlet stores a number
without sending it.

.. code-block:: dart

   static const String gFunction

``.function``: A breakpoint function, for drawing envelopes and curves.
It stores sorted (x, y, curve) points, answers an x with the y between
them, and on a bang sends the whole shape as a ramp for .line or .bline.
Its points are saved with the patch.

.. code-block:: dart

   static const String gInt

``.i``: An integer number box. A number on the left inlet stores it and
sends it, a bang sends it again, and the right inlet stores a number
without sending it. Floats are truncated.

.. code-block:: dart

   static const String gIncdec

``.incdec``: A stepper over a whole number. 'inc' and 'dec', or a signed
step count on the middle inlet, move the value inside a range that
clamps or wraps; a number sets it without sending and a bang sends it.

.. code-block:: dart

   static const String gKslider

``.kslider``: A piano keyboard. A pitch on the left inlet presses that
key at the stored velocity and sends velocity and pitch; velocity 0
releases it. The state is the velocity held on each of the 128 keys.

.. code-block:: dart

   static const String gList

``.l``: A list box. A bang sends the stored list; a list arriving on the
inlet replaces it without sending it.

.. code-block:: dart

   static const String gLed

``.led``: A labelled on/off indicator. It latches by default (a number
sets it, a bang flips it) or registers presses with the 'momentary'
keyword, and sends its state and its label.

.. code-block:: dart

   static const String gMessage

``.m``: A message box. A bang sends the stored text as the message it
spells: a number, a bang, a list or a command. A message arriving on the
inlet replaces the text without sending it.

.. code-block:: dart

   static const String gMatrixctrl

``.matrixctrl``: A grid of cells, columns by rows, such as a step
pattern or a routing patchbay. '\<column\> \<row\> \<value\>' sets a
cell, and every change is sent in that same form, so the grid can drive
.matrix or .router directly.

.. code-block:: dart

   static const String gMultislider

``.multislider``: A bank of sliders, such as the steps of a sequencer or
the bands of an equaliser. A list sets the cells and the bank size, 'set
\<index\> \<value\>' sets one cell, and every message sends the whole
bank as a list.

.. code-block:: dart

   static const String gNodes

``.nodes``: Blends between circular nodes in a 2D field. Move a cursor
with 'x y' and it sends each node's distance and a weight that falls
from 1 at the node's centre to 0 at its edge, scaled so the weights add
up to 1.

.. code-block:: dart

   static const String gNslider

``.nslider``: A note on a staff: a pitch and how it is spelled. It sends
the pitch and its accidental (1 sharp, -1 flat, 0 natural); a black key
follows the 'spelling' argument unless a message chooses otherwise.

.. code-block:: dart

   static const String gPreset

``.preset``: Stores and recalls snapshots of the patch's controls.
'store \<n\>' captures every control whose value can be restored into
slot n, and a number recalls that slot. The slots are saved with the
patch.

.. code-block:: dart

   static const String gRadiogroup

``.radiogroup``: Radio buttons, or check boxes with 'multi', over named
items. It works exactly like .umenu; a host draws it as a group of
buttons.

.. code-block:: dart

   static const String gRslider

``.rslider``: A range control: two ends inside minimum-maximum, such as
a key split or a velocity layer. It sends the lower end, the higher end
and both as a list, whichever way round the ends were set.

.. code-block:: dart

   static const String gSlider

``.slider``: A slider holding a position from 0 to 1. A number sets the
position, clamped to that range, and sends it; a bang sends it again.

.. code-block:: dart

   static const String gToggle

``.t``: An on/off toggle. An int sets it (0 is off, any other number
on), a bang flips it, and every message sends the state as 0 or 1.

.. code-block:: dart

   static const String gTab

``.tab``: A row of tabs over named items. It works exactly like .umenu;
a host draws it as tabs.

.. code-block:: dart

   static const String gText

``.text``: A comment in the patch. It holds its text for a host to
display and has no inlets or outlets.

.. code-block:: dart

   static const String gTextbutton

``.textbutton``: A button carrying a text label. It works exactly like
.led; a host draws it as a labelled button instead of a lamp.

.. code-block:: dart

   static const String gTextedit

``.textedit``: An editable text field. Text arriving on the inlet
replaces the stored text and is sent on; a bang sends it again. It holds
up to 256 characters.

.. code-block:: dart

   static const String gUmenu

``.umenu``: A menu of named items. A number or an item name selects an
item, and it sends the item number, its name and the whole selection.
With 'multi', several items can be selected at once.

.. code-block:: dart

   static const String gXyslider

``.xyslider``: A two-dimensional pad holding an x and a y, each inside
its own bounds, so two parameters move as one gesture. It sends x, y and
the pair as a list.

.. code-block:: dart

   static const String gBline

``.bline``: Ramps a number to a target one step per bang, so whatever
bangs it sets the pace. A list of target/count pairs makes a ramp of
several segments; the right outlet bangs when the last target is
reached.

.. code-block:: dart

   static const String gClocker

``.clocker``: While running, sends the time since it was started, in
milliseconds, every interval (5 ms by default). With a clock bound, a
second outlet sends the beats that clock has moved in the same time.

.. code-block:: dart

   static const String gDelay

``.delay``: Sends a bang a set time after it receives one: 5 ms by
default, or a beat time on a domain clock. It holds one bang at a time;
a new bang restarts the wait and 'stop' cancels it.

.. code-block:: dart

   static const String gLine

``.line``: Ramps a number to a target over a given time, sending a value
every grain (20 ms by default) and a bang from the right outlet on
arrival. A list of target/time pairs makes a ramp of several segments.

.. code-block:: dart

   static const String gMetro

``.metro``: Sends a bang at a regular interval while it runs, starting
with one bang the moment it starts. The interval is in milliseconds
(1000 by default) or a beat time on a domain clock.

.. code-block:: dart

   static const String gPipe

``.pipe``: Delays ints, floats and lists by a set time (0 ms by
default). It holds up to 64 values at once, and each one keeps the delay
it arrived with.

.. code-block:: dart

   static const String gQlim

``.qlim``: Limits how often messages pass. A message that arrives before
the interval since the last output is up is held and sent when it is up;
a newer message replaces it, or with 'usurp 0' joins a queue.

.. code-block:: dart

   static const String gQuickthresh

``.quickthresh``: Collects values that arrive close together into one
list, sent a fixed time (40 ms by default) after the first of them. Made
for grouping the notes of a chord.

.. code-block:: dart

   static const String gSetclock

``.setclock``: Creates a named domain clock that runs from the start,
and sets its tempo: every number it receives is the new tempo in BPM. A
bang sends the clock's beat position.

.. code-block:: dart

   static const String gSpeedlim

``.speedlim``: Limits how often messages pass. A message that arrives
before the interval since the last output is up is dropped, so a burst
comes out as its first message.

.. code-block:: dart

   static const String gTempo

``.tempo``: Counts notes on a named domain clock: '.tempo main 120 1 16'
sends 0 to 15 in sixteenth notes, over and over. Starting it sets the
clock's tempo.

.. code-block:: dart

   static const String gThresh

``.thresh``: Collects values that arrive close together into one list,
and sends the list once no new value has arrived for the threshold (10
ms by default).

.. code-block:: dart

   static const String gTimepoint

``.timepoint``: Sends a bang once when a named domain clock passes a
beat position, as in '.timepoint main 128'.

.. code-block:: dart

   static const String gTimer

``.timer``: Measures the time between a bang in the left inlet and a
bang in the right inlet, in milliseconds and, with a clock name as
argument, in beats.

.. code-block:: dart

   static const String gTranslate

``.translate``: Converts a time value between milliseconds, hertz,
samples, beats and ticks. Converting between real time and beats uses
the current tempo of a named domain clock.

.. code-block:: dart

   static const String gTransport

``.transport``: Starts, stops and sets the tempo of a named domain
clock, creating the clock (stopped) if it does not exist yet. A bang
sends the clock's beat position and tempo.

.. code-block:: dart

   static const String gWhen

``.when``: On any input, sends the beat position and tempo of a named
domain clock. It only reads the clock and never creates one.

.. code-block:: dart

   static const String mBendin

``.bendin``: MIDI pitch-bend input at 7-bit resolution: reports the
pitch wheel as 0-127 with 64 at rest. .xbendin reports the full 14 bits.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mBendout

``.bendout``: Builds a 7-bit MIDI pitch-bend message for .midiout: 0-127
with 64 at rest. .xbendout sends the full 14 bits.

.. code-block:: dart

   static const String mBorax

``.borax``: Reports statistics about a stream of notes: serial number,
voice, how many notes are sounding, durations and the time between
attacks.

.. code-block:: dart

   static const String mChanPress

``.channelpressure``: Builds a MIDI channel-aftertouch message for
.midiout. Each pressure value on the inlet sends one message.

.. code-block:: dart

   static const String mControl

``.controlchange``: Builds a MIDI control-change message for .midiout.
Each value on the inlet sends one message, on the controller and channel
the arguments set.

.. code-block:: dart

   static const String mCtlin

``.ctlin``: MIDI control-change input. Reports the value, controller
number and channel of every control change received on a MIDI input
port: knobs, faders, wheels and pedals.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mFlush

``.flush``: Passes pitch/velocity pairs through and remembers which
notes are sounding. A bang releases them all with velocity 0.

.. code-block:: dart

   static const String mMakenote

``.makenote``: Plays a note: sends a pitch and velocity now, and the
same pitch with velocity 0 after a duration in milliseconds.

.. code-block:: dart

   static const String mMidiflush

``.midiflush``: Passes a MIDI byte stream through and remembers which
notes it left sounding. A bang sends a note-off for each of them.

.. code-block:: dart

   static const String mFormat

``.midiformat``: Builds raw MIDI messages from notes, controllers,
program changes, pressure and pitch bend. The inverse of .midiparse;
each message leaves as a list of byte values.

.. code-block:: dart

   static const String mIn

``.midiin``: Raw MIDI input. Every byte received on a MIDI input port
leaves the outlet as an int, in arrival order and uninterpreted.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mMidiinfo

``.midiinfo``: Lists the machine's MIDI ports. A bang sends the number
of ports, then an index and a name for each, so a patch can find a
device by name.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mOut

``.midiout``: Sends MIDI messages to an output port. Each list on the
inlet is one message, as byte values or as built by the MIDI sender
objects; a few words send common channel-mode messages.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mParse

``.midiparse``: Splits a raw MIDI byte stream into notes, controllers,
program changes, pressure, pitch bend and channel. Messages it does not
decode leave the rightmost outlet as bytes.

.. code-block:: dart

   static const String mMpeconfig

``.mpeconfig``: Builds the MPE configuration message that tells a device
how many member channels an MPE zone uses. A value on the inlet sends
it.

.. code-block:: dart

   static const String mMpeformat

``.mpeformat``: Builds MPE messages: notes, per-note pitch bend,
pressure and slide, on the member channel set by the right inlet. The
inverse of .mpeparse.

.. code-block:: dart

   static const String mMpeparse

``.mpeparse``: Reads an MPE MIDI stream and reports notes, per-note
pitch bend, pressure and slide, each with its channel and the channel's
role in the zone.

.. code-block:: dart

   static const String mNotein

``.notein``: MIDI note input. Every note-on and note-off received on a
MIDI input port leaves as pitch, velocity and channel; a release reports
velocity 0.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mNoteOff

``.noteoff``: Builds a MIDI note-off message for .midiout. A pitch on
the left inlet sends it, with the release velocity stored on the right
inlet.

.. code-block:: dart

   static const String mNoteOn

``.noteon``: Builds a MIDI note-on message for .midiout. A pitch on the
left inlet sends it, with the velocity stored on the right inlet;
velocity 0 is a release.

.. code-block:: dart

   static const String mNrpnin

``.nrpnin``: Non-registered parameter (NRPN) input. Follows the control
changes that select and write a device's own parameter, and reports each
value written with its parameter number and channel.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mNrpnout

``.nrpnout``: Writes a 14-bit value to a non-registered parameter
(NRPN), a device's own parameter, as four MIDI control-change messages
for .midiout.

.. code-block:: dart

   static const String mOffer

``.offer``: Stores x,y pairs of ints and hands each y back once: an x
with no y waiting looks up its pair, sends the y and deletes the pair.

.. code-block:: dart

   static const String mPgmin

``.pgmin``: MIDI program-change input. Reports each program change
received on a MIDI input port as 1-128, the numbering most devices
display.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mPoly

``.poly``: Assigns notes to a numbered pool of voices. Each note-on
takes a free voice, and its release comes out with the same voice
number.

.. code-block:: dart

   static const String mPolyin

``.polyin``: MIDI polyphonic key-pressure input. Reports the pressure on
each held key separately, as pitch, pressure and channel.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mPolyPress

``.polypressure``: Builds a MIDI polyphonic key-pressure message for
.midiout. A pitch on the left inlet sends it, with the pressure stored
on the right inlet.

.. code-block:: dart

   static const String mProgChange

``.programchange``: Builds a MIDI program-change message for .midiout.
Each program number on the inlet, 0-127 as on the wire, sends one
message.

.. code-block:: dart

   static const String mRpnin

``.rpnin``: Registered parameter (RPN) input. Follows the control
changes that select and write a parameter, and reports each value
written with its parameter number and channel.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mRpnout

``.rpnout``: Writes a 14-bit value to a registered parameter (RPN), such
as pitch-bend range, as four MIDI control-change messages for .midiout.

.. code-block:: dart

   static const String mRtin

``.rtin``: MIDI clock input. Reports the system real-time messages a
sequencer or drum machine sends: timing clock, start, continue, stop and
reset.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mStripnote

``.stripnote``: Passes note-ons and drops releases: a pitch goes through
only when its velocity is not 0.

.. code-block:: dart

   static const String mSustain

``.sustain``: A sustain pedal for pitch/velocity pairs. While the pedal
is down, releases are held back; lifting it sends them all.

.. code-block:: dart

   static const String mSxformat

``.sxformat``: Builds a system-exclusive message from a template of
constant bytes, placeholders filled from the inlets, and an optional
checksum.

.. code-block:: dart

   static const String mSysexin

``.sysexin``: System-exclusive input. Every byte of every
system-exclusive message received on a MIDI input port leaves as an int,
from 240 to 247; other messages are filtered out.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mTouchin

``.touchin``: MIDI channel-aftertouch input. Reports the pressure on the
keys after they are down, as one value for the whole channel.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mXbendin

``.xbendin``: MIDI pitch-bend input at full 14-bit resolution: reports
the pitch wheel as 0-16383 with 8192 at rest.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mXbendin2

``.xbendin2``: MIDI pitch-bend input reported as its two bytes: the
coarse byte, with 64 at rest, and the fine byte below it. Pairs with
.xbendout2.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mXbendout

``.xbendout``: Builds a 14-bit MIDI pitch-bend message for .midiout:
0-16383 with 8192 at rest.

.. code-block:: dart

   static const String mXbendout2

``.xbendout2``: Builds a 14-bit MIDI pitch-bend message for .midiout
from its coarse and fine bytes, the form .xbendin2 reports.

.. code-block:: dart

   static const String mXctlin

``.xctlin``: 14-bit MIDI control-change input. Combines controllers 0-31
with their fine partners 32-63 and reports each move as one value of
0-16383.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mXctlout

``.xctlout``: Sends a 14-bit controller value as two MIDI control-change
messages for .midiout: the coarse half on controller 0-31, then the fine
half on that number plus 32.

.. code-block:: dart

   static const String mXmidiin

``.xmidiin``: Raw MIDI input framed into messages. Each complete message
received on a MIDI input port leaves as one list of byte values, such as
144 60 100.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mXnotein

``.xnotein``: MIDI note input with release velocity. Reports pitch,
velocity, release velocity and channel; a note-off reports velocity 0
and how fast the key came up.

Holds a MIDI port: only in builds with MIDI device
support (not macOS / Android).

.. code-block:: dart

   static const String mXnoteout

``.xnoteout``: Builds a MIDI note message with release velocity for
.midiout. A velocity above 0 sends a note-on; 0 sends a note-off
carrying the release velocity.

.. code-block:: dart

   static const String gBucket

``.bucket``: A shift register for numbers. Each number pushes the stored
values one outlet along and every outlet sends what it holds, each one a
step older than the outlet to its left.

.. code-block:: dart

   static const String gCycle

``.cycle``: Sends each message out the next outlet in turn, going back
to outlet 0 after the last. Use it to deal notes across a bank of voices
or to alternate between processing chains.

.. code-block:: dart

   static const String gDecode

``.decode``: Sends 1 out the selected outlet and 0 out all the others,
to switch a bank of which exactly one member is on. Two more inlets
override the selection: one turns every outlet on, the other mutes them
all.

.. code-block:: dart

   static const String gFunnel

``.funnel``: Merges several inlets onto one outlet, putting the inlet's
number in front of each message so the receiver knows where it came
from. The inverse of .spray.

.. code-block:: dart

   static const String gGate

``.gate``: Passes messages from its right inlet out one of its outlets,
chosen by a number in the left inlet. Outlets count from 1; 0 closes the
gate.

.. code-block:: dart

   static const String gMatrix

``.matrix``: Routes messages from its data inlets to its outlets as set
by connection messages, like .router, but each connection has a gain
that scales the numbers passing through. At a gain of 1 messages pass
unchanged.

.. code-block:: dart

   static const String gRoute

``.route``: Sends a message out the outlet whose selector matches its
first item, with that item removed. A message that matches no selector
leaves the rightmost outlet unchanged.

.. code-block:: dart

   static const String gRoutepass

``.routepass``: Sends a whole message out the outlet whose selector
matches its first item, keeping that item on. A message that matches no
selector leaves the rightmost outlet unchanged.

.. code-block:: dart

   static const String gRouter

``.router``: Routes messages from its data inlets to its outlets,
unchanged, as set by connection messages. Any inlet can reach any number
of outlets, and the routing can change while the patch runs.

.. code-block:: dart

   static const String gSel

``.sel``: Bangs the outlet whose selector matches the input. Anything
that matches no selector leaves the rightmost outlet unchanged.

.. code-block:: dart

   static const String gSplit

``.split``: Sends a number out the left outlet when it lies between low
and high, and out the right outlet when it does not. Both limits are
inclusive, and the number is not changed.

.. code-block:: dart

   static const String gSpray

``.spray``: Takes a list whose first number is an outlet index and sends
the values after it out that outlet and the ones to its right. The
inverse of .funnel.

.. code-block:: dart

   static const String gSwitch

``.switch``: Passes messages from one of its right-hand inlets to the
outlet, chosen by a number in the left inlet. Inlets count from 1; 0
closes the switch.

.. code-block:: dart

   static const String gBangbang

``.bangbang``: Sends a bang out every outlet, right to left, whatever
arrives. Each outlet's branch finishes before the next outlet fires, so
it orders 'do this, then that'.

.. code-block:: dart

   static const String gBondo

``.bondo``: Holds one value per inlet and sends all of them, right to
left, whenever any inlet receives one. Keeps a set of related values
together, so nothing downstream sees half an update.

.. code-block:: dart

   static const String gBuddy

``.buddy``: Waits until every inlet has received a value, then sends
them all at once, right to left, and starts waiting again. Use it to
assemble one event from parts that arrive separately.

.. code-block:: dart

   static const String gIf

``.if``: Tests a condition and sends one message when it is true and,
optionally, another when it is false: '$i1 \> 64 then bang else out2
$i1'. The condition and the message items use the .expr language.

.. code-block:: dart

   static const String gLoadbang

``.loadbang``: Sends a bang when the patch it is in has finished
loading, so a saved patch can set up its own starting state. A bang at
the inlet sends one by hand.

.. code-block:: dart

   static const String gLoadmess

``.loadmess``: Sends its arguments as a message when the patch it is in
has finished loading, such as '.loadmess 0.5' to set a gain. A bang at
the inlet sends it by hand.

.. code-block:: dart

   static const String gMatch

``.match``: Watches a stream of numbers and sends the last few as a list
when they match the pattern in its arguments. The word 'nn' matches any
number, so '.match 1 nn 3' sends '1 5 3' after 1, 5, 3.

.. code-block:: dart

   static const String gNext

``.next``: Tells the first message of a burst from the rest: a bang
leaves the left outlet when a message starts a new logical event, and
the right outlet when it belongs to the same event as the message before
it.

.. code-block:: dart

   static const String gOnebang

``.onebang``: A one-shot: lets one message through as a bang from the
left outlet, then sends every further message out the right outlet until
the right inlet re-arms it.

.. code-block:: dart

   static const String gTrigger

``.trigger``: Sends its input out every outlet, right to left, converted
per outlet to an int, a float, a bang, a list or text, or replaced by a
constant. Use it to make the order of two branches explicit.

.. code-block:: dart

   static const String gUzi

``.uzi``: Sends a burst of bangs at once, each preceded by its index,
then a carry bang when the run is done. The patcher's loop: '.uzi 16'
runs sixteen iterations inside one message.

.. code-block:: dart

   static const String gAppend

``.append``: Puts a stored message after every message that arrives and
sends the result as one list. Use it to add fixed trailing arguments,
such as a channel number, to a computed value.

.. code-block:: dart

   static const String gIter

``.iter``: Sends the items of a list out one at a time, first to last,
so objects that take single numbers can process each one. A bang sends
the last list again.

.. code-block:: dart

   static const String gJoin

``.join``: Joins the messages held by several inlets into one list, end
to end. Unlike .pack, each inlet holds a whole message of any length.
.unjoin splits a list the other way.

.. code-block:: dart

   static const String gListfunnel

``.listfunnel``: Sends each item of a list out as a two-item list: its
index, then the item. Use it to address items by position with .route,
.sel or .spray.

.. code-block:: dart

   static const String gPack

``.pack``: Combines values arriving at separate inlets into one list,
one element per inlet. Each creation argument sets an element's type and
starting value. Only the leftmost inlet sends the list; .pak sends from
every inlet.

.. code-block:: dart

   static const String gPak

``.pak``: Combines values arriving at separate inlets into one list, and
sends the list whenever any inlet receives a value. Otherwise the same
as .pack.

.. code-block:: dart

   static const String gPrepend

``.prepend``: Puts a stored message in front of every message that
arrives and sends the result as one list. Use it to put a selector word
such as 'note' or 'set' in front of a computed value.

.. code-block:: dart

   static const String gSubstitute

``.substitute``: Replaces every item of a message that equals the match
with the replacement, anywhere in the message. A message with a
replacement leaves the left outlet; one with no match leaves the right
outlet unchanged.

.. code-block:: dart

   static const String gUnjoin

``.unjoin``: Splits a list into groups of equal size, one group per
outlet, and sends whatever is left over out the rightmost outlet.
Nothing is dropped. The reverse of .join.

.. code-block:: dart

   static const String gUnpack

``.unpack``: Splits a list into its items and sends each one out its own
outlet, right to left. Each creation argument sets an outlet's type and
starting value. The reverse of .pack.

.. code-block:: dart

   static const String gZl

``.zl``: A list processor with 31 modes: measure, reorder, pick from,
search, compare, combine, accumulate or sum a list. The mode word is the
first argument and can be changed with 'mode \<name\>'.

.. code-block:: dart

   static const String gAtoi

``.atoi``: Converts a message into the character codes of its text and
holds them: 'hi' gives 104 105. A bang sends the held codes again, and
the other two inlets add to them or replace them without sending.

.. code-block:: dart

   static const String gCombine

``.combine``: Joins the items held in its inlets into one symbol, with
nothing between them. Each creation argument is an item and the starting
value of its own inlet. By default inlet 0 sends and the other inlets
only store.

.. code-block:: dart

   static const String gFromsymbol

``.fromsymbol``: Splits a symbol on its separator into a message: with
separator /, voice/3/freq becomes 'voice 3 freq'. A result that is one
number or the word bang leaves as an int, a float or a bang. The inverse
of .tosymbol.

.. code-block:: dart

   static const String gItoa

``.itoa``: Converts character codes into the text they spell and holds
it: 104 105 gives 'hi'. A bang sends the held text again, and the other
two inlets add to it or replace it without sending. The inverse of
.atoi.

.. code-block:: dart

   static const String gRegexp

``.regexp``: Matches messages against a regular expression. Each match
leaves with its capture groups, an optional substitution rewrites every
match, and a message that does not match leaves the rightmost outlet
unchanged.

.. code-block:: dart

   static const String gSpell

``.spell``: Spells a message out as the character codes of its text,
sent as one list: 'hi' gives 104 105. Optional arguments pad a short
result to a minimum length with a fill code.

.. code-block:: dart

   static const String gSprintf

``.sprintf``: Builds a message from a format with printf-style
placeholders: '.sprintf /voice/%d/freq' sends /voice/3/freq for a 3.
Each placeholder has its own inlet; inlet 0 formats and sends, the
others only store.

.. code-block:: dart

   static const String gTolower

``.tolower``: Converts the letters A-Z in a message to lower case and
leaves everything else as it was: other characters, spacing and tokens.
Put it in front of a .route or .sel to make the match ignore case.

.. code-block:: dart

   static const String gTosymbol

``.tosymbol``: Joins the tokens of a message into one symbol, with the
separator between them: with separator /, 'voice 3 freq' becomes
voice/3/freq. A number or a bang becomes the text that spells it.

.. code-block:: dart

   static const String gToupper

``.toupper``: Converts the letters a-z in a message to upper case and
leaves everything else as it was: other characters, spacing and tokens.
The mirror of .tolower.

.. code-block:: dart

   static const String gBag

``.bag``: Holds a collection of numbers that a patch adds to and removes
from, such as the notes currently held down. A bang sends every number,
newest first.

.. code-block:: dart

   static const String gCapture

``.capture``: Records every value that reaches it, in arrival order, so
a patch can be run and then asked what went past. When full, the oldest
item makes room for the newest.

.. code-block:: dart

   static const String gColl

``.coll``: Stores messages at number or symbol addresses and sends them
back on request: presets, note tables, cue lists. All .coll objects with
the same name share one collection.

.. code-block:: dart

   static const String gFunbuff

``.funbuff``: Stores (x, y) pairs of ints sorted by x, and sends the y
for any x: the stored y, or the one at the nearest lower x. 'interp'
interpolates between points; 'next' steps through them in order.

.. code-block:: dart

   static const String gTable

``.table``: A fixed-size array of ints addressed by index, for
wavetables, curves and step sequences. It can also be read as a
probability distribution: a bang picks a weighted random address.

.. code-block:: dart

   static const String gTextfile

``.textfile``: Collects incoming messages as lines of text: each message
is added to the current line and 'cr' ends it. Lines can be sent back
one at a time or all at once, and read from or written to a text file.

.. code-block:: dart

   static const String gDict

``.dict``: A key/value store shared by name. Keys nest with '::'
(voice::1::freq), a value is any message, and the contents are saved
with the patch. A bang sends the reference 'dictionary \<name\>' that
the other .dict objects take.

.. code-block:: dart

   static const String gDictCompare

``.dict.compare``: Compares two named dictionaries and sends 1 when they
hold the same entries, 0 when they do not. On a difference, the key
paths that differ follow from the right outlet.

.. code-block:: dart

   static const String gDictDeserialize

``.dict.deserialize``: Fills a named dictionary from JSON text,
replacing its contents, and sends its reference. Takes a JSON object as
a message, or 'read \<file\>' for a larger document.

.. code-block:: dart

   static const String gDictGroup

``.dict.group``: Groups a named dictionary's entries by value into a
target dictionary, as '\<group\>::\<original path\>'. With a key
argument, each record is grouped by the value it holds at that key.

.. code-block:: dart

   static const String gDictIter

``.dict.iter``: Walks a named dictionary, sending one '\<path\>
\<value\>' list per entry, then a bang from the right outlet when it is
done.

.. code-block:: dart

   static const String gDictJoin

``.dict.join``: Merges two named dictionaries into a target dictionary:
the left one's entries, overlaid with the right one's. Where both hold a
key path, the right value wins.

.. code-block:: dart

   static const String gDictPack

``.dict.pack``: Builds a named dictionary from its inlets, one inlet per
key path: '.dict.pack synth freq gain'. The left inlet stores its value,
writes the dictionary and sends its reference; the other inlets only
store.

.. code-block:: dart

   static const String gDictPrint

``.dict.print``: Prints a named dictionary to the engine log as indented
JSON, one line per row, each line labelled with the dictionary's name. A
debugging aid with no outlets.

.. code-block:: dart

   static const String gDictRoute

``.dict.route``: Sends a named dictionary's reference out of the outlet
of the first key argument it holds, or out of the rightmost outlet when
it holds none. Use it to send dictionaries of different shapes to
different parts of a patch.

.. code-block:: dart

   static const String gDictSerialize

``.dict.serialize``: Sends a named dictionary as one line of JSON text.
'write \<file\>' saves the same JSON to a file instead, for a dictionary
too large to send as a message.

.. code-block:: dart

   static const String gDictSlice

``.dict.slice``: Splits a named dictionary at a key path. Entries under
the path go into the slice dictionary with the path removed from their
keys; all other entries go into the remainder dictionary.

.. code-block:: dart

   static const String gDictStrip

``.dict.strip``: Removes every entry under a key path from a named
dictionary, in place, then sends its reference. An entry stored at
exactly the path is kept.

.. code-block:: dart

   static const String gDictUnpack

``.dict.unpack``: Sends the values at a named dictionary's key paths out
of separate outlets, one outlet per key path argument, right to left.
The inverse of .dict.pack.

.. code-block:: dart

   static const String gArray

``.array``: An ordered list of values, shared by every .array with the
same name in a patcher. Messages add, change, fetch and remove elements
by zero-based index; a bang sends the array's reference, which the other
.array objects accept.

.. code-block:: dart

   static const String gArrayAt

``.array.at``: Outputs the element at a position in a named array. Send
a position to fetch it, or a list of positions to fetch several at once;
a bang fetches the last position again. A position the array does not
have bangs the miss outlet.

.. code-block:: dart

   static const String gArrayChange

``.array.change``: Reports whether a named array has changed since it
was last polled. Each bang sends 1 or 0, and on a change also sends the
array's reference, so work further down only runs when something moved.

.. code-block:: dart

   static const String gArrayCompare

``.array.compare``: Compares two named arrays. A bang sends 1 when they
hold the same elements in the same order, and 0 when they do not.

.. code-block:: dart

   static const String gArrayConcat

``.array.concat``: Outputs the elements of two named arrays as one list:
the left array followed by the right. Neither array is changed.

.. code-block:: dart

   static const String gArrayDeserialize

``.array.deserialize``: Fills a named array from a JSON array such as
\[60,62.5,"kick"\], replacing its contents. The text is parsed in the
background, and the array's reference is sent once the new contents are
in place.

.. code-block:: dart

   static const String gArrayEvery

``.array.every``: Tests every number in a named array with an
expression. A bang sends 1 when the expression is true (non-zero) for
all of them, and 0 when it is false for any.

.. code-block:: dart

   static const String gArrayExpr

``.array.expr``: Evaluates an expression for each element of a named
array and sends the results as one list, for example $i1 + 12 to
transpose. The array itself is not changed.

.. code-block:: dart

   static const String gArrayFill

``.array.fill``: Fills a named array with a number of copies of one
value, replacing its contents. Use it to clear an array, or to give it a
size before writing to it by position.

.. code-block:: dart

   static const String gArrayFilter

``.array.filter``: Removes from a named array every element for which an
expression is false (zero), keeping the rest in order. Words are removed
too, because the expression only sees numbers.

.. code-block:: dart

   static const String gArrayFlatten

``.array.flatten``: Outputs the elements of several named arrays as one
list, in the order the arrays are named, up to 16 arrays. None of the
arrays is changed.

.. code-block:: dart

   static const String gArrayForeach

``.array.foreach``: Evaluates an expression for each element of a named
array and sends the results one at a time, first to last, then bangs its
done outlet.

.. code-block:: dart

   static const String gArrayGroup

``.array.group``: Groups the equal elements of a named array. A bang
sends one list per distinct value, holding that value as many times as
it occurs, then bangs the done outlet.

.. code-block:: dart

   static const String gArrayIndex

``.array.index``: Looks up a value in a named array. The position of the
first matching element leaves the left outlet; when no element matches,
the right outlet bangs.

.. code-block:: dart

   static const String gArrayIndexmap

``.array.indexmap``: Reorders a named array by a list of positions: the
new array holds the elements at those positions, in that order.
Positions may repeat or be left out.

.. code-block:: dart

   static const String gArrayIndexof

``.array.indexof``: Outputs the position of the first element of a named
array that matches a value, or -1 when no element matches.

.. code-block:: dart

   static const String gArrayInsert

``.array.insert``: Inserts a value or a list into a named array at a
stored position, moving later elements up. Set the position on the
middle inlet, then send what to insert to the left inlet.

.. code-block:: dart

   static const String gArrayIter

``.array.iter``: Sends the elements of a named array one at a time,
first to last, then bangs its done outlet. Use it to do something for
each element.

.. code-block:: dart

   static const String gArrayJoin

``.array.join``: Joins the elements of a named array into a single word,
with an optional separator between them: c4 e4 g4 joined with - gives
c4-e4-g4.

.. code-block:: dart

   static const String gArrayLength

``.array.length``: Outputs the number of elements in a named array when
it receives a bang.

.. code-block:: dart

   static const String gArrayMap

``.array.map``: Applies an expression to every numeric element of a
named array and writes the results back, for example $i1 + 12 to
transpose. Words stay where they are.

.. code-block:: dart

   static const String gArrayMax

``.array.max``: Outputs the largest number in a named array. Words are
skipped.

.. code-block:: dart

   static const String gArrayMean

``.array.mean``: Outputs the average of the numbers in a named array, as
a float. Words are skipped.

.. code-block:: dart

   static const String gArrayMedian

``.array.median``: Outputs the median of the numbers in a named array,
as a float. Words are skipped, and the array itself is not reordered.

.. code-block:: dart

   static const String gArrayMin

``.array.min``: Outputs the smallest number in a named array. Words are
skipped.

.. code-block:: dart

   static const String gArrayMode

``.array.mode``: Outputs the element that occurs most often in a named
array. Words count too, and elements are compared by spelling, so 7 and 7.
are different elements.

.. code-block:: dart

   static const String gArrayPop

``.array.pop``: Removes the last element of a named array and outputs
it. On an empty array, the empty outlet bangs instead.

.. code-block:: dart

   static const String gArrayPush

``.array.push``: Appends a value or a list to the end of a named array,
then sends the array's reference. With .array.pop it makes a stack, with
.array.shift a queue.

.. code-block:: dart

   static const String gArrayRandom

``.array.random``: Outputs a randomly chosen element of a named array. A
seed makes the sequence of picks repeat on every run.

.. code-block:: dart

   static const String gArrayReduce

``.array.reduce``: Combines the numbers in a named array into one value
with an expression, such as $f1 + $f2 for a sum. $f1 is the result so
far and $f2 the next element.

.. code-block:: dart

   static const String gArrayRegexp

``.array.regexp``: Outputs the elements of a named array that match a
regular expression, as one list. When nothing matches, the right outlet
bangs. The array itself is not changed.

.. code-block:: dart

   static const String gArrayRemove

``.array.remove``: Removes the element at a position from a named array
and outputs it; later elements move down. A position the array does not
have bangs the miss outlet.

.. code-block:: dart

   static const String gArrayReplace

``.array.replace``: Replaces every occurrence of a value in a named
array with another value. Sends how many elements were replaced, then
the array's reference.

.. code-block:: dart

   static const String gArrayReverse

``.array.reverse``: Reverses the order of the elements of a named array,
then sends the array's reference.

.. code-block:: dart

   static const String gArrayRotate

``.array.rotate``: Rotates the elements of a named array by a number of
positions, wrapping around the ends. Positive amounts move elements
toward the end, negative toward the start.

.. code-block:: dart

   static const String gArrayRoutepass

``.array.routepass``: Routes a named array by what it contains: its
reference leaves the outlet of the first listed value the array holds,
or the rightmost outlet when it holds none of them.

.. code-block:: dart

   static const String gArrayScramble

``.array.scramble``: Shuffles the elements of a named array into a
random order, and sends the order it applied so another array can be put
in the same order. The same object as .array.shuffle.

.. code-block:: dart

   static const String gArraySect

``.array.sect``: Outputs the elements two named arrays have in common,
each once, as one list in the left array's order. Neither array is
changed.

.. code-block:: dart

   static const String gArrayShift

``.array.shift``: Removes the first element of a named array and outputs
it; the other elements move down one position. On an empty array, the
empty outlet bangs instead.

.. code-block:: dart

   static const String gArrayShuffle

``.array.shuffle``: Shuffles the elements of a named array into a random
order, and sends the order it applied so another array can be put in the
same order. The same object as .array.scramble.

.. code-block:: dart

   static const String gArraySlice

``.array.slice``: Outputs a range of elements of a named array, from a
start position up to but not including an end position. The array itself
is not changed.

.. code-block:: dart

   static const String gArraySome

``.array.some``: Tests the numbers in a named array with an expression.
A bang sends 1 when the expression is true (non-zero) for at least one
of them, and 0 when it is true for none.

.. code-block:: dart

   static const String gArraySort

``.array.sort``: Sorts the elements of a named array, ascending or
descending, with numbers before words. Also sends the order it applied,
so another array can be put in the same order.

.. code-block:: dart

   static const String gArraySplit

``.array.split``: Splits a named array in two at a position: the
elements before it leave the left outlet and the rest leave the right
outlet, right first. The array itself is not changed.

.. code-block:: dart

   static const String gArrayStddev

``.array.stddev``: Outputs the standard deviation of the numbers in a
named array, as a float. Words are skipped.

.. code-block:: dart

   static const String gArrayStream

``.array.stream``: Appends incoming values to a named array and keeps
only the most recent ones: a sliding window of a set size. Sends the
array's reference each time the window is full.

.. code-block:: dart

   static const String gArraySub

``.array.sub``: Outputs a range of elements of a named array, both ends
included; with the end before the start, the range is sent in reverse.
The same object as .array.subarray.

.. code-block:: dart

   static const String gArraySubarray

``.array.subarray``: Outputs a range of elements of a named array, both
ends included; with the end before the start, the range is sent in
reverse. The same object as .array.sub.

.. code-block:: dart

   static const String gArrayThin

``.array.thin``: Removes elements of a named array that repeat the
element kept before them. With a tolerance, numbers that close to it
count as repeats too, which thins out a stream of values that barely
change.

.. code-block:: dart

   static const String gArrayTolist

``.array.tolist``: Outputs all elements of a named array as one list. An
array of one element sends that element as a single int, float or
symbol.

.. code-block:: dart

   static const String gArrayTostring

``.array.tostring``: Outputs all elements of a named array as one text
message, separated by spaces. Unlike .array.tolist, a single number is
sent as text, ready for objects that work on text.

.. code-block:: dart

   static const String gArrayTosymbol

``.array.tosymbol``: Joins all elements of a named array, without
spaces, into one symbol: kick and .wav become kick.wav. The result is
always a symbol, even when it looks like a number.

.. code-block:: dart

   static const String gArrayTuplewise

``.array.tuplewise``: Combines two named arrays position by position
with an expression, such as $f1 + $f2, and outputs the results as one
list. The result is as long as the shorter array.

.. code-block:: dart

   static const String gArrayUnion

``.array.union``: Outputs the elements held by either of two named
arrays, each once, as one list. Neither array is changed.

.. code-block:: dart

   static const String gArrayUnique

``.array.unique``: Outputs the elements of a named array with repeats
removed, each at its first occurrence. The array itself is not changed.

.. code-block:: dart

   static const String gArrayUnshift

``.array.unshift``: Inserts a value or a list at the front of a named
array, moving the other elements up, then sends the array's reference.

.. code-block:: dart

   static const String gArrayWrap

``.array.wrap``: Outputs the element at a position in a named array,
wrapping around: positions past the end start again at the beginning,
and -1 is the last element.

.. code-block:: dart

   static const String gDecide

``.decide``: A coin flip: each bang sends 0 or 1 with equal chance. Use
it for random branching, fills and gating.

.. code-block:: dart

   static const String gDrunk

``.drunk``: A random walk: each bang moves the value up or down by a
small random step and sends it, kept within 0 to range-1. Successive
values drift rather than jump.

.. code-block:: dart

   static const String gProb

``.prob``: A Markov chain of weighted transitions between numbered
states. Each bang jumps from the current state to a next one, chosen by
weight, and sends it.

.. code-block:: dart

   static const String gRandom

``.random``: Sends a random integer from 0 to range-1 on each bang,
every value equally likely.

.. code-block:: dart

   static const String gUrn

``.urn``: Random numbers without repeats: each bang sends a number from
0 to limit-1 that has not come out yet, like dealing from a shuffled
deck. When all have been sent, the right outlet bangs.

.. code-block:: dart

   static const String gForward

``.forward``: Sends what arrives to every .r with a given name, like .s,
but the name can be changed with a message to the right inlet. Sends
nothing until it has a destination.

.. code-block:: dart

   static const String gPrint

``.print``: Writes every message that arrives to the engine log, one
line each, with a name in front. Use it to watch values pass through a
patch.

.. code-block:: dart

   static const String gReceive

``.r``: Sends out whatever is sent to its name: by a .s or .forward in
this patcher or in a patcher with the same name, by the host's PassData,
or on the named bus.

.. code-block:: dart

   static const String gSend

``.s``: Sends what arrives to every .r with the same name, without a
cord. It also publishes on the named bus as
'patcher.\<patcherName\>.\<name\>', so other patchers and the host can
listen.

.. code-block:: dart

   static const String gValue

``.value``: Holds a value shared by every .value with the same name. A
value at the inlet is stored for all of them without being sent; a bang
sends out what is stored.

.. code-block:: dart

   static const String dAdc

``~adc``: The patch's audio input. When the patcher runs as an insert
effect, each outlet carries one channel of the audio it processes.

.. code-block:: dart

   static const String dDac

``~dac``: The patch's audio output. Each inlet is one output channel,
passed on to the sound or insert that hosts the patcher. A patch is
silent until a signal reaches this object.

.. code-block:: dart

   static const String gInlet

``.inlet``: A message inlet of the subpatcher it is in. With index N,
whatever the parent sends to the subpatcher's inlet N comes out of this
object, inside the subpatcher.

.. code-block:: dart

   static const String gOutlet

``.outlet``: A message outlet of the subpatcher it is in. With index N,
whatever arrives here leaves the subpatcher through its outlet N.

.. code-block:: dart

   static const String patcher

``patcher``: A subpatcher: groups part of a patch into one object that
the parent connects to by pin number. Its pins are the .inlet, .outlet,
~inlet and ~outlet objects placed inside it.

.. code-block:: dart

   static const String dInlet

``~inlet``: A signal inlet of the subpatcher it is in. With index N, the
signal the parent connects to the subpatcher's inlet N comes out of this
object, inside the subpatcher.

.. code-block:: dart

   static const String dOutlet

``~outlet``: A signal outlet of the subpatcher it is in. With index N,
the signal that arrives here leaves the subpatcher through its outlet N.

.. code-block:: dart

   static const String gMtr

``.mtr``: A multi-track recorder for messages: records what arrives on
each track inlet with its timing, and plays it back out of the matching
outlet in the same rhythm. Each track can be recorded, played, muted and
stepped on its own.

.. code-block:: dart

   static const String gQlist

``.qlist``: A cue list: lines of numbers and messages played back in
time. A line of numbers is sent out and its first number is the wait
before the next line; a line starting with a word is sent to the
receivers of that name.

.. code-block:: dart

   static const String gSeq

``.seq``: Records a stream of raw MIDI bytes with its timing and plays
it back. Reads and writes standard MIDI files; playback can follow its
own clock, incoming ticks or a YSE domain clock.

.. code-block:: dart

   static const List<String> all

Every constant above, in registry (type-name) order.

Static methods
--------------

.. code-block:: dart

   static bool isValid(String type)

Whether [type] is a known object type identifier.

