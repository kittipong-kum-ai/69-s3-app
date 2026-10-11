import type { Event } from '@strapi/database';

const encodeMobile = (value: string): string =>
  Buffer.from(value, 'utf8').toString('base64');

const decodeMobile = (value: string): string =>
  Buffer.from(value, 'base64').toString('utf8');

const maskLast3 = (value: string): string =>
  value.length > 3 ? `${value.slice(0, -3)}xxx` : value;

export default {
  beforeCreate(event: Event) {
    const { data } = event.params;
    if (data?.mobile) {
      data.mobile = encodeMobile(data.mobile);
    }
  },

  beforeUpdate(event: Event) {
    const { data } = event.params;
    if (data?.mobile) {
      data.mobile = encodeMobile(data.mobile);
    }
  },

  afterFindOne(event: Event) {
    if (event.result?.mobile) {
      event.result.mobile = maskLast3(decodeMobile(event.result.mobile));
    }
    if (event.result?.CardID) {
      event.result.CardID = maskLast3(event.result.CardID);
    }
    console.log('[student] afterFindOne mobile:', event.result?.mobile, '| CardID:', event.result?.CardID);
  },

  afterFindMany(event: Event) {
    if (Array.isArray(event.result)) {
      event.result.forEach((entry) => {
        if (entry?.mobile) {
          entry.mobile = maskLast3(decodeMobile(entry.mobile));
        }
        if (entry?.CardID) {
          entry.CardID = maskLast3(entry.CardID);
        }
      });
    }
    console.log(
      '[student] afterFindMany:',
      JSON.stringify(event.result?.map((entry: { mobile?: string; CardID?: string }) => ({ mobile: entry.mobile, CardID: entry.CardID })))
    );
  },
};
