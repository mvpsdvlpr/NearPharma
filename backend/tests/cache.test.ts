import Cache from '../src/cache';

describe('Cache', () => {
  it('should set and get values', () => {
    const cache = new Cache<number>();
    cache.set('a', 123, 1000);
    expect(cache.get('a')).toBe(123);
  });

  it('should expire values after TTL', (done) => {
    const cache = new Cache<number>();
    cache.set('b', 456, 10);
    setTimeout(() => {
      expect(cache.get('b')).toBeUndefined();
      done();
    }, 20);
  });

  it('should delete values', () => {
    const cache = new Cache<number>();
    cache.set('c', 789, 1000);
    cache.delete('c');
    expect(cache.get('c')).toBeUndefined();
  });

  it('should clear all values', () => {
    const cache = new Cache<number>();
    cache.set('d', 1, 1000);
    cache.set('e', 2, 1000);
    cache.clear();
    expect(cache.get('d')).toBeUndefined();
    expect(cache.get('e')).toBeUndefined();
  });
});
