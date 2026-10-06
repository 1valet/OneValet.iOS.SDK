// Intentionally empty.
//
// This target exists only so Swift Package Manager links TwilioVideo — which the
// OneValetSDK binary references — into the consuming app. `.binaryTarget`s can't
// declare dependencies, so this anchor target carries the Twilio dependency on
// their behalf. There is no public API here; consumers `import OneValetSDK`.
