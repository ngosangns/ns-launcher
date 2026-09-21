type IconProps = { size?: number; className?: string };

export function SparkleIcon({ size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 3.2 13.4 9 19 10.5 13.4 12 12 17.8 10.6 12 5 10.5 10.6 9Z" />
    </svg>
  );
}

export function BookIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M6 4.5A2.5 2.5 0 0 1 8.5 2H20v16.5H8.7c-.9 0-1.7.6-1.7 1.5H20V22H8.5A4.5 4.5 0 0 1 4 17.5v-11A2.5 2.5 0 0 1 6 4.5Z" />
    </svg>
  );
}

export function ShieldIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 2 20 6v6.2c0 5-3.4 8.6-8 10.3C7.4 20.8 4 17.2 4 12.2V6l8-4Z" />
    </svg>
  );
}

export function HomeIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 3.2 21 11h-2.2V21h-5.2v-6.2H10.4V21H5.2V11H3L12 3.2Z" />
    </svg>
  );
}

export function PersonIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 12a4.2 4.2 0 1 0-4.2-4.2A4.2 4.2 0 0 0 12 12Zm0 2.2c-4 0-8 2-8 5.3V21h16v-1.5c0-3.3-4-5.3-8-5.3Z" />
    </svg>
  );
}
