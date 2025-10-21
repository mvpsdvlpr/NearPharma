import Cache from '../src/cache';

describe('Cache', () => {
  it('should set and get values', async () => {
    const cache = new Cache<number>();
    await cache.set('a', 123, 1000);
    expect(await cache.get('a')).toBe(123);
  });

  it('should expire values after TTL', (done) => {
    const cache = new Cache<number>();
    cache.set('b', 456, 10).then(() => {
      setTimeout(async () => {
        expect(await cache.get('b')).toBeUndefined();
        done();
      }, 20);
    });
  });

  it('should delete values', async () => {
    const cache = new Cache<number>();
    await cache.set('c', 789, 1000);
    await cache.delete('c');
    expect(await cache.get('c')).toBeUndefined();
  });

  it('should clear all values', async () => {
    const cache = new Cache<number>();
    await cache.set('d', 1, 1000);
    await cache.set('e', 2, 1000);
    cache.clear();
    expect(await cache.get('d')).toBeUndefined();
    expect(await cache.get('e')).toBeUndefined();
  });
});
