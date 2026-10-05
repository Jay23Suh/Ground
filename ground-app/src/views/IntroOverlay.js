import { useEffect, useState } from 'react'
import { ReactComponent as LegoIcon } from '../lego.svg'

const LINES = [
  'we are all busy with something.',
  "it's important to ground ourselves —",
  'be grateful. be present.',
  'get to know yourself.',
]

const POINTS = [
  ['◷', 'every couple of hours, while ground is open in a tab, a prompt appears asking you to check in with yourself.'],
  ['✎', 'you can also write anytime with "write now" on the home page.'],
  ['❖', 'memories hold the moments you want to keep — share one with a friend and see what they remember.'],
  ['✦', 'after a week and 10 entries, your abstract unlocks — a visual review of your journey.'],
]

export default function IntroOverlay({ onDone }) {
  const [step, setStep] = useState(0)
  const [visible, setVisible] = useState(false)
  const canNotify = 'Notification' in window && Notification.permission === 'default'

  useEffect(() => {
    setVisible(false)
    const t = setTimeout(() => setVisible(true), 50)
    return () => clearTimeout(t)
  }, [step])

  const next = () => (step === 1 && !canNotify ? onDone() : setStep(s => s + 1))

  return (
    <div className={`intro-overlay${visible ? ' intro-visible' : ''}`}>
      <div className="intro-content">
        {step === 0 && (
          <>
            <LegoIcon className="intro-icon" />
            <h1 className="intro-title">ground</h1>
            {LINES.map((line, i) => <p key={line} className={`intro-line intro-line--${i + 1}`}>{line}</p>)}
            <button className="intro-btn" onClick={next}>next →</button>
          </>
        )}
        {step === 1 && (
          <>
            <h1 className="intro-title">how it works</h1>
            <ul className="intro-points">
              {POINTS.map(([icon, text], i) => (
                <li key={text} className="intro-point" style={{ transitionDelay: `${300 + i * 200}ms` }}>
                  <span className="intro-point-icon" aria-hidden="true">{icon}</span>{text}
                </li>
              ))}
            </ul>
            <button className="intro-btn" onClick={next}>{canNotify ? 'next →' : "let's begin"}</button>
          </>
        )}
        {step === 2 && (
          <>
            <h1 className="intro-title">stay grounded</h1>
            <p className="intro-line intro-line--1">ground can nudge you with a notification when it's time to check in — as long as the tab is open.</p>
            <button className="intro-btn" onClick={async () => { await Notification.requestPermission(); onDone() }}>enable notifications</button>
            <button className="intro-skip" onClick={onDone}>not now</button>
          </>
        )}
        <div className="intro-dots" aria-hidden="true">
          {Array.from({ length: canNotify ? 3 : 2 }, (_, i) => <span key={i} className={`intro-dot${i === step ? ' on' : ''}`} />)}
        </div>
      </div>
    </div>
  )
}
