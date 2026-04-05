# readme-imess

A small Swift CLI that generates custom animated iMessage-style assets for more aesthetically pleasing GitHub READMEs.

It takes a simple JSON config and outputs:

- An animated SVG for crisp README embeds
- An optional animated GIF rendered natively on macOS

For now, `readme-imess` is macOS-only because the generator depends on native Apple graphics and font APIs.

## What It Does

You define your own chat messages, colors, timing, and title/description metadata, then run one command to generate a ready-to-embed asset!

The generator handles:

- Alternating left/right bubbles
- Automatic bubble sizing
- Line wrapping for longer messages
- A typing indicator intro
- Optional delivered/status text
- Transparent or custom backgrounds

## Sample Output

Generated from [examples/ktnguyenx.json](/Users/khanhnguyen/Downloads/college/projects/readme-imess/examples/ktnguyenx.json):

### SVG Version

<p align="center">
  <img src="./assets/sample-output.svg" width="92%" alt="Animated iMessage-style SVG sample" />
</p>

<p align="center">
  Sharp, lightweight, and usually the best choice for GitHub README embeds.
</p>

### GIF Version

<p align="center">
  <img src="./assets/sample-output.gif" width="92%" alt="Animated iMessage-style GIF sample" />
</p>

<p align="center">
  A more pixelated, 8-bit-style export if you want a softer retro look.
</p>

## Quick Start

### 1. Generate a starter config

```bash
swift run readme-imess init examples/my-profile.json
```

### 2. Edit the messages in your config

Example config:

```json
{
  "title": "Animated iMessage-style README conversation for Your Name",
  "typingIndicator": {
    "enabled": true,
    "side": "left"
  },
  "messages": [
    { "side": "left", "text": "Hi, I'm Your Name!" },
    { "side": "right", "text": "I build thoughtful software.", "status": "Delivered" },
    { "side": "left", "text": "Customize these messages to match your README." }
  ]
}
```

### 3. Generate an SVG

```bash
swift run readme-imess generate examples/my-profile.json
```

By default, that writes an SVG to `output/my-profile.svg`.

### 4. Generate both SVG and GIF

```bash
swift run readme-imess generate examples/my-profile.json \
  --svg output/my-profile.svg \
  --gif output/my-profile.gif
```

## Using It With A Profile README

If your special profile repo is cloned inside this project, you can write directly into its assets folder:

```bash
swift run readme-imess generate examples/ktnguyenx.json \
  --svg ktnguyenx/assets/readme-chat.svg \
  --gif ktnguyenx/assets/readme-chat.gif
```

Then embed it in your profile README:

```html
<p align="center">
  <img src="./assets/readme-chat.svg" width="100%" alt="Animated iMessage-style README conversation" />
</p>
```

If you want to use the GIF instead, switch the `src` to `./assets/readme-chat.gif`.

## Config Reference

Top-level fields:

- `title`: Accessible SVG title text.
- `description`: Accessible SVG description text.
- `animationSeconds`: Total loop duration. Defaults to `12`.
- `messages`: Required array of chat bubbles.
- `typingIndicator`: Optional typing bubble config.
- `theme`: Optional colors.
- `canvas`: Optional layout tuning.
- `gif`: Optional GIF export settings.

Each message supports:

- `side`: `"left"` or `"right"`
- `text`: bubble text
- `status`: optional status label shown below the bubble
- `bubbleColor`: optional per-message override
- `textColor`: optional per-message override

Theme fields:

- `incomingBubbleColor`
- `outgoingBubbleColor`
- `incomingTextColor`
- `outgoingTextColor`
- `statusColor`
- `backgroundColor`

Canvas fields:

- `width`
- `height`
- `sideInset`
- `topInset`
- `bottomInset`
- `bubbleGap`
- `maxBubbleWidthRatio`
- `fontSize`

GIF fields:

- `fps`
- `scale`
- `loopCount`

## Included Example

The repo includes a ready-to-run example based on my current `ktnguyenx` profile content:

```bash
swift run readme-imess generate examples/ktnguyenx.json
```

## Notes

- GIF export uses native macOS drawing, so this project is currently macOS-focused.
- SVG is usually the best default for README usage because it stays sharp and is often smaller.
