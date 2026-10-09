#!/bin/bash
# Kjøres PÅ draupnir fra repo-rot: Scripts/mac-test.sh [core|ios|mac|device]
#   core   — AppCore-testene native på macOS (ingen simulator, ingen signering)
#   ios    — full simulator-runde: xcodegen → xcodebuild test → xcresult-summary
#   mac    — bygg macOS-appen (kompileringssjekk for Mac-flaten)
#   device — signert iOS-bygg (cloud signing via ASC API-nøkkel); .app-sti på stdout
set -euo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
cd "$SD/.."
export PATH="/opt/homebrew/bin:$PATH"
. "$SD/wt-lib.sh"
MODE="${1:-core}"

# Worktree-nøkkelen. Her på draupnir ER mappenavnet nøkkelen (remote-test.sh
# synker til build/<nøkkel>), men remote-test sender den også eksplisitt.
# Alt som kan kollidere mellom parallelle worktrees henger på denne.
WT="${DEVRIG_WT:-$(basename "$PWD")}"
DD="/tmp/dd-$WT"

case "$MODE" in
  core)
    swift test --package-path apple/AppCore
    ;;
  ios|mac|device)
    xcodegen generate --spec apple/project.yml --project apple >/dev/null

    # To xcodebuild på samme DerivedData korrumperer den. Låsen tas FØR
    # byggeplassen — motsatt rekkefølge kan vranglåse to bygg i samme tre.
    wt_lock "dd-$WT"

    if [ "$MODE" = "device" ]; then
      # Signering er GLOBALT eksklusiv, ikke bare per worktree: build.keychain
      # deles av alle trær, og to samtidige -allowProvisioningUpdates-bygg
      # lager foreldreløse «Created via API»-sertifikater hos Apple som må
      # revokes manuelt før neste forsøk virker. Én om gangen, alltid.
      wt_lock devrig-signing

      ASC_KEY_ID="${ASC_KEY_ID:-NJHCL5LW99}"
      ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
      ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de91-3fdc-47e3-e053-5b8c7c11a4d1}"
      DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-7W88EES2X8}"

      # Dedikert build-keychain: lås opp i DENNE sesjonen (lås-tilstand deles
      # ikke mellom SSH-sesjoner på macOS 26). Passordet er keychainens eget,
      # ikke login-passordet. Oppsett: se dev-rig 21.09 AGENTS.md.
      KCPW_FILE="$HOME/.config/devrig/build-keychain-pass"
      KC="$HOME/Library/Keychains/build.keychain-db"
      security unlock-keychain -p "$(cat "$KCPW_FILE")" "$KC"
      xcodebuild build \
        -project apple/App.xcodeproj \
        -scheme App \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$DD" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        -quiet
      # Gi codesign varig, promptfri tilgang til signeringsnøkkelen (idempotent;
      # nødvendig første gang etter at Xcode har opprettet nøkkelen).
      security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
        -k "$(cat "$KCPW_FILE")" "$KC" >/dev/null 2>&1 || true

      APP="$DD/Build/Products/Debug-iphoneos/App.app"
      codesign -dv "$APP" 2>&1 | grep -E "^(Authority|TeamIdentifier)" | head -3 >&2
      echo "$APP"
      exit 0
    fi

    if [ "$MODE" = "mac" ]; then
      wt_slot bygg "${DEVRIG_MAX_BUILDS:-2}"
      xcodebuild build \
        -project apple/App.xcodeproj \
        -scheme App-macOS \
        -destination "platform=macOS" \
        -derivedDataPath "$DD" \
        -quiet
      echo '{"result":"Built","scheme":"App-macOS"}'
      exit 0
    fi

    # Tak på samtidige bygg: hver bootet simulator koster 1–2 GB RAM, og
    # xcodebuild spiser alle kjernene. Uten taket svelter byggeverten når
    # flere worktrees jobber samtidig.
    wt_slot bygg "${DEVRIG_MAX_BUILDS:-2}"

    # Egen simulator per worktree — aldri «første ledige iPhone». Se wt-sim.sh.
    UDID="$(bash "$SD/wt-sim.sh" "$WT")"

    xcrun simctl bootstatus "$UDID" -b >/dev/null
    RESULT="/tmp/$WT-$(date +%s).xcresult"
    set +e
    xcodebuild test \
      -project apple/App.xcodeproj \
      -scheme App \
      -destination "id=$UDID" \
      -derivedDataPath "$DD" \
      -resultBundlePath "$RESULT" \
      -quiet
    STATUS=$?
    set -e
    xcrun xcresulttool get test-results summary --path "$RESULT"
    exit $STATUS
    ;;
  *)
    echo "usage: $0 [core|ios|mac|device]" >&2
    exit 64
    ;;
esac
