import { Card } from './types';

export type Grade = 'Again' | 'Good' | 'Easy';

export function calculateNextReview(card: Card, grade: Grade): Card {
  const now = Date.now();
  let { interval, ease, reps } = card;

  if (grade === 'Again') {
    reps = 0;
    interval = 1; // 1 day
    ease = Math.max(1.3, ease - 0.2);
  } else if (grade === 'Good') {
    reps += 1;
    if (reps === 1) interval = 1;
    else if (reps === 2) interval = 6;
    else interval = Math.round(interval * ease);
  } else if (grade === 'Easy') {
    reps += 1;
    ease += 0.15;
    if (reps === 1) interval = 4;
    else interval = Math.round(interval * ease * 1.3);
  }

  // Convert interval days to milliseconds for next review
  const nextReview = now + (interval * 24 * 60 * 60 * 1000);

  return {
    ...card,
    interval,
    ease,
    reps,
    nextReview
  };
}
