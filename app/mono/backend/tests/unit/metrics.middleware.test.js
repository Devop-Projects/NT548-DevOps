jest.mock('../../src/config/metrics', () => ({
  httpRequestsTotal: {
    inc: jest.fn(),
  },
  httpRequestDuration: {
    startTimer: jest.fn(() => jest.fn()),
  },
}));

const metricsMiddleware = require('../../src/middleware/metrics.middleware');
const {
  httpRequestsTotal,
  httpRequestDuration,
} = require('../../src/config/metrics');

describe('metrics.middleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should skip /metrics endpoint', () => {
    const req = {
      path: '/metrics',
    };

    const res = {};

    const next = jest.fn();

    metricsMiddleware(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(httpRequestDuration.startTimer).not.toHaveBeenCalled();
  });

  it('should record metrics on normal request', () => {
    const finishHandlers = {};

    const req = {
      path: '/api/tasks',
      method: 'GET',
      route: {
        path: '/tasks',
      },
      baseUrl: '/api',
    };

    const res = {
      statusCode: 200,
      on: jest.fn((event, cb) => {
        finishHandlers[event] = cb;
      }),
    };

    const next = jest.fn();

    metricsMiddleware(req, res, next);

    expect(next).toHaveBeenCalled();

    finishHandlers.finish();

    expect(httpRequestsTotal.inc).toHaveBeenCalledWith({
      method: 'GET',
      route: '/api/tasks',
      status_code: 200,
    });
  });
});
