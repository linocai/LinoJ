// ===============================================================
// iOS Settings — full-screen modal sliding up
// Uses iOS grouped list pattern
// ===============================================================

function IosSettingsView({ mode = 'light' }) {
  const t = I_TOKENS[mode];

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: t.bg, color: t.ink,
      overflow: 'auto', paddingBottom: 40,
    }}>
      {/* Top bar */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 5,
        paddingTop: 56,
        background: mode === 'light' ? 'rgba(244,243,239,0.85)' : 'rgba(0,0,0,0.85)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
      }}>
        <div style={{
          display: 'flex', alignItems: 'center',
          padding: '10px 16px 12px',
        }}>
          <button style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: t.inkSoft, fontSize: 16, fontWeight: 500,
            fontFamily: I_FONT, padding: 0,
          }}>Cancel</button>
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{
              fontFamily: I_DISPLAY, fontSize: 16, fontWeight: 600,
              letterSpacing: '-0.01em',
            }}>Settings</div>
          </div>
          <button style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: t.ink, fontSize: 16, fontWeight: 700,
            fontFamily: I_FONT, padding: 0,
          }}>Done</button>
        </div>
      </div>

      {/* Sections */}
      <div style={{ padding: '12px 16px 0' }}>

        <IosListGroup label="Account" t={t} mode={mode}>
          <IosSettingRow t={t} label="Apple Account" value="lin@example.com" chevron/>
          <IosSettingRow t={t} label="iCloud sync" toggle={true} hint="Required for iPhone + Mac in sync." last/>
        </IosListGroup>

        <IosListGroup label="General" t={t} mode={mode}>
          <IosSettingRow t={t} label="Appearance"
            value="System"
            valueMute="locked"
            hint="Follows your iPhone display setting."/>
          <IosSettingRow t={t} label="Default tab on launch" value="Main" chevron/>
          <IosSettingRow t={t} label="Default scope for new todos" value="Company" chevron/>
          <IosSettingRow t={t} label="Show completed in counts" toggle={false} last/>
        </IosListGroup>

        <IosListGroup label="Notifications" t={t} mode={mode}
          hint="Heads-ups about events. Todos never bug you on a clock.">
          <IosSettingRow t={t} label="Heads-up before event" value="30 min" chevron/>
          <IosSettingRow t={t} label="System banner too" toggle={true}/>
          <IosSettingRow t={t} label="Yesterday's missed events" toggle={true}/>
          <IosSettingRow t={t} label="Daily summary" value="8:00 AM" chevron/>
          <IosSettingRow t={t} label="Quiet hours" value="10 PM \u2014 7 AM" chevron last/>
        </IosListGroup>

        <IosListGroup label="Sync to other apps" t={t} mode={mode}>
          <IosSettingRow t={t} label="Apple Calendar" toggle={false}
            hint="Mirror LinoJ events to Calendar.app."/>
          <IosSettingRow t={t} label="Apple Reminders" toggle={false}
            hint="Mirror todos to Reminders.app." last/>
        </IosListGroup>

        <IosListGroup label="About" t={t} mode={mode}>
          <IosSettingRow t={t} label="Version" value="1.0.0 (240)" valueMono/>
          <IosSettingRow t={t} label="Release notes" chevron/>
          <IosSettingRow t={t} label="Send feedback" chevron/>
          <IosSettingRow t={t} label="Privacy policy" chevron/>
          <IosSettingRow t={t} label="Acknowledgements" chevron last/>
        </IosListGroup>

        <div style={{
          padding: '24px 0 12px', textAlign: 'center',
        }}>
          <button style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: '#ff5f57', fontSize: 14, fontWeight: 600,
            fontFamily: I_FONT, padding: 0,
          }}>Sign out</button>
        </div>
        <div style={{
          padding: '8px 0 22px', textAlign: 'center',
          fontSize: 11, color: t.inkMute, fontWeight: 500,
          fontFamily: I_MONO,
        }}>LinoJ \u00b7 v1.0.0</div>
      </div>
    </div>
  );
}

function IosListGroup({ label, hint, t, mode, children }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <div style={{
        fontSize: 11, fontWeight: 700, color: t.inkMute,
        textTransform: 'uppercase', letterSpacing: '0.08em',
        padding: '0 6px 8px',
      }}>{label}</div>
      <div style={{
        background: t.panel,
        border: `0.5px solid ${t.border}`,
        borderRadius: 12, overflow: 'hidden',
      }}>{children}</div>
      {hint && (
        <div style={{
          fontSize: 11.5, color: t.inkMute, padding: '8px 6px 0',
          fontWeight: 500, lineHeight: 1.4,
        }}>{hint}</div>
      )}
    </div>
  );
}

function IosSettingRow({ t, label, value, valueMute, valueMono, toggle, hint, chevron, last }) {
  return (
    <div style={{
      padding: '12px 14px',
      borderBottom: last ? 'none' : `0.5px solid ${t.border}`,
      cursor: 'pointer',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{
          fontSize: 14, fontWeight: 500, color: t.ink,
          letterSpacing: '-0.005em',
        }}>{label}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          {value && (
            <span style={{
              fontFamily: valueMono ? I_MONO : I_FONT,
              fontSize: 13.5, color: t.inkSoft, fontWeight: 500,
            }}>{value}</span>
          )}
          {valueMute && (
            <span style={{
              fontFamily: I_MONO, fontSize: 10.5, color: t.inkDim,
              padding: '1px 6px', borderRadius: 3, background: t.chip,
            }}>{valueMute}</span>
          )}
          {toggle !== undefined && <IosToggle on={toggle} t={t}/>}
          {chevron && (
            <svg width="8" height="12" viewBox="0 0 8 12" fill="none" style={{ opacity: 0.4 }}>
              <path d="M2 2l4 4-4 4" stroke="currentColor" strokeWidth="1.4"
                fill="none" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          )}
        </div>
      </div>
      {hint && (
        <div style={{
          fontSize: 11.5, color: t.inkMute, marginTop: 4, fontWeight: 500,
          lineHeight: 1.4, maxWidth: 280,
        }}>{hint}</div>
      )}
    </div>
  );
}

function IosToggle({ on, t }) {
  return (
    <div style={{
      width: 46, height: 28, borderRadius: 14,
      background: on ? t.ink : t.chip,
      position: 'relative', cursor: 'pointer',
      border: on ? 'none' : `0.5px solid ${t.border}`,
      transition: 'background 0.15s',
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 20 : 2,
        width: 24, height: 24, borderRadius: '50%',
        background: on ? t.bg : t.panel,
        boxShadow: '0 1px 3px rgba(0,0,0,0.18)',
        transition: 'left 0.18s',
      }}/>
    </div>
  );
}

Object.assign(window, {
  IosSettingsView, IosListGroup, IosSettingRow, IosToggle,
});
